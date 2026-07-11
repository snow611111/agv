"""
RTSP → HLS + FLV 双模 relay server.
HLS: ffmpeg → .ts → Python serves files → hls.js
FLV: GET /flv/cam1 → Python spawns ffmpeg → pipes FLV → mpegts.js
"""
import subprocess, sys, os, shutil, time, threading, urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn

class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    pass

LOCAL_FFMPEG = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ffmpeg.exe')
FALLBACK_FFMPEG = r'C:\Users\天久\.marscode\ai-chat\binary\1.6.38\modules\ai-agent\ffmpeg.exe'
FFMPEG = LOCAL_FFMPEG if os.path.isfile(LOCAL_FFMPEG) else FALLBACK_FFMPEG
HLS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'hls_output')
ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
PORT = 8088

CAMERAS = [
    ('摄像头1', 'rtsp://admin:Admin123@192.168.2.14:554'),
    ('摄像头2', 'rtsp://admin:Admin123@192.168.2.13:554'),
    ('摄像头3', 'rtsp://admin:Admin123@192.168.2.12:554'),
    ('摄像头4', 'rtsp://admin:Admin123@192.168.2.11:554'),
]

def start_hls(name, rtsp_url, index):
    cam_dir = os.path.join(HLS_DIR, f'cam{index}')
    os.makedirs(cam_dir, exist_ok=True)
    for f in os.listdir(cam_dir):
        os.remove(os.path.join(cam_dir, f))
    cmd = [
        FFMPEG, '-rtsp_transport', 'tcp', '-i', rtsp_url,
        '-c:v', 'copy', '-an',
        '-hls_time', '2', '-hls_list_size', '12',
        '-hls_flags', 'omit_endlist+append_list',
        '-hls_segment_filename', os.path.join(cam_dir, 'seg_%03d.ts'),
        os.path.join(cam_dir, 'index.m3u8'),
    ]
    print(f'[HLS] {name} started')
    while True:
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            proc.wait()
            print(f'[HLS] {name} ffmpeg stopped (code={proc.returncode}), restart in 2s')
            time.sleep(2)
        except Exception as e:
            print(f'[HLS] {name} error: {e}')
            time.sleep(2)

def stream_flv(rtsp_url, wfile):
    cmd = [FFMPEG, '-fflags', 'nobuffer', '-flags', 'low_delay',
           '-rtsp_transport', 'tcp', '-i', rtsp_url,
           '-c:v', 'copy', '-an', '-f', 'flv', 'pipe:1']
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        while True:
            data = proc.stdout.read(8192)
            if not data: break
            try:
                wfile.write(data)
            except (BrokenPipeError, ConnectionResetError, OSError):
                break
        proc.terminate()
        proc.wait()
    except Exception as e:
        print(f'[FLV] stream error: {e}')

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        # Filter out noise
        msg = args[0] if args else ''
        if '/flv/' not in str(msg) and '/hls_output/' not in str(msg):
            print(f'[HTTP] {self.command} {self.path} -> {msg}')

    def send_cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_cors()
        self.end_headers()

    def do_GET(self):
        path = self.path.split('?')[0]
        print(f'[HTTP] GET {path}')

        # === FLV streaming ===
        if path.startswith('/flv/cam'):
            try:
                idx = int(path.split('/flv/cam')[1]) - 1
                if 0 <= idx < len(CAMERAS):
                    name, rtsp_url = CAMERAS[idx]
                    print(f'[FLV] -> {name} (cam{idx+1})')
                    self.send_response(200)
                    self.send_header('Content-Type', 'video/x-flv')
                    self.send_header('Connection', 'close')
                    self.send_cors()
                    self.end_headers()
                    stream_flv(rtsp_url, self.wfile)
                    print(f'[FLV] {name} disconnected')
                    return
            except ValueError:
                pass
            self.send_error(400, 'Bad camera index')
            return

        # === Static file serving ===
        file_path = os.path.join(ROOT_DIR, path.lstrip('/'))
        # If path starts with /folder_name/, look directly in that sibling folder
        path_parts = path.lstrip('/').split('/')
        if len(path_parts) >= 2 and not os.path.isfile(file_path):
            folder = path_parts[0]
            rest = '/'.join(path_parts[1:])
            folder_path = os.path.join(os.path.dirname(ROOT_DIR), folder, rest)
            if os.path.isfile(folder_path):
                file_path = folder_path
        # Also check sibling folders as fallback
        if not os.path.isfile(file_path):
            for sub in ['current_control', 'error_detect', 'xunjian_task', 'task_list']:
                alt = os.path.join(os.path.dirname(ROOT_DIR), sub, path.lstrip('/'))
                if os.path.isfile(alt):
                    file_path = alt
                    break
        if os.path.isfile(file_path):
            content_types = {
                '.html': 'text/html', '.js': 'application/javascript',
                '.css': 'text/css', '.m3u8': 'application/vnd.apple.mpegurl',
                '.ts': 'video/mp2t', '.jpg': 'image/jpeg', '.png': 'image/png',
                '.json': 'application/json',
                '.wasm': 'application/wasm',
            }
            ext = os.path.splitext(file_path)[1].lower()
            ctype = content_types.get(ext, 'application/octet-stream')
            try:
                with open(file_path, 'rb') as f:
                    data = f.read()
                self.send_response(200)
                self.send_header('Content-Type', ctype)
                self.send_header('Content-Length', len(data))
                self.send_header('Cache-Control', 'no-cache')
                self.send_cors()
                self.end_headers()
                self.wfile.write(data)
            except Exception as e:
                self.send_error(500, str(e))
            return

        # 404
        self.send_error(404, f'Not found: {path}')

if __name__ == '__main__':
    print('=' * 55)
    print('  RTSP → HLS / FLV  Relay  v2')
    print('=' * 55)

    if os.path.exists(HLS_DIR):
        shutil.rmtree(HLS_DIR)
    os.makedirs(HLS_DIR)

    for i, (name, url) in enumerate(CAMERAS):
        threading.Thread(target=start_hls, args=(name, url, i+1), daemon=True).start()

    # Background cleaner: remove .ts files older than 60s, runs every 30s
    def clean_old_segments():
        while True:
            time.sleep(30)
            try:
                now = time.time()
                for cam in range(1, len(CAMERAS) + 1):
                    cam_dir = os.path.join(HLS_DIR, f'cam{cam}')
                    if not os.path.isdir(cam_dir):
                        continue
                    for f in os.listdir(cam_dir):
                        if f.endswith('.ts'):
                            fp = os.path.join(cam_dir, f)
                            if now - os.path.getmtime(fp) > 60:
                                os.remove(fp)
            except Exception as e:
                print(f'[Cleaner] error: {e}')
    threading.Thread(target=clean_old_segments, daemon=True).start()

    print('Waiting for HLS init...')
    time.sleep(4)
    for i in range(1, 5):
        d = os.path.join(HLS_DIR, f'cam{i}')
        fs = os.listdir(d) if os.path.exists(d) else []
        print(f'  HLS cam{i}: {fs}')

    print(f'\n  http://127.0.0.1:{PORT}/cam_flv.html   (低延迟 FLV)')
    print(f'  http://127.0.0.1:{PORT}/cam_test.html   (双模)')
    print(f'{"="*55}\n')

    server = ThreadingHTTPServer(('0.0.0.0', PORT), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nShutdown.')
        server.shutdown()
