# Plugin source

Place project-owned plugin directories under this folder. The local Compose override mounts this directory writable at `/var/www/html/wp-content/plugins`; the server override mounts the same checked-out revision read-only.

Do not place uploads, database exports, secrets, vendor credentials, or production-only content here.
