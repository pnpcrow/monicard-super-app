# Development Guide

## Commands

```bash
npm install
npm start
npm run dev
npm test
```

## Design rules

- Keep BLE transport independent from protocol construction.
- Keep protocol builders deterministic and side-effect free.
- Do not report device success until an application-level response is decoded.
- Keep unsupported or unsafe features visibly disabled rather than simulated.
- Update documentation with every feature or protocol change.
- Avoid framework dependencies unless they remove more complexity than they add.

## API endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | Runtime health |
| GET | `/api/content/:type` | Local informational content |
| GET | `/api/firmware/latest` | Firmware metadata only |
| POST | `/api/feedback` | Store local feedback record |
| GET | `/docs/` | Browser documentation index |

## Release checklist

1. Run tests.
2. Start the server and request `/api/health`.
3. Open the SPA in desktop Chrome and test all routes.
4. Test one mobile viewport.
5. Switch through all five locales.
6. Verify no unimplemented operation claims success.
7. Confirm FILE and OTA remain disabled unless a hardware validation release explicitly enables them.
8. Update `README.md`, `Docs/`, and version metadata.
