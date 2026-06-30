# Frontend Env Setup

This project now reads runtime-related addresses from `.env`.

Main keys:

- `VITE_API_BASE`: AGV backend base path or URL
- `VITE_IMG_BASE`: flaw image base URL
- `VITE_RTC_BASE`: stream service base path or URL
- `VITE_EASY_API_BASE`: camera service base path or URL
- `VITE_EASY_AUTH`: camera service Authorization header
- `VITE_DIFY_*`: AI analysis service config
- `VITE_REPORT_AI_*`: inspection report generation workflow config

Typical workflow on another computer:

1. Open `.env`
2. Update the addresses and keys for that environment
3. Restart `npm.cmd run dev:frontend`

If you use local proxy paths like `/prod-api`, `/webrtc-api`, `/easy-api`, keep them as-is and only ensure your local reverse proxy or backend mapping is available.
