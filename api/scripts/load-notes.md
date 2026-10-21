# Load test notes

Install optional: `npx autocannon -c 20 -d 20 http://localhost:3000/api/health`

Club scale (~2–5k members, low concurrent): single `t4g.small` API + `db.t4g.small` is a starting point. Scale EB horizontally before vertical DB. Enable Redis for Socket.IO when concurrent websocket clients exceed ~1–2k.
