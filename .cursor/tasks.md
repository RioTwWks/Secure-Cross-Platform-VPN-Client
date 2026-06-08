# Project Tasks - MVP

## Completed
- [x] Project structure created
- [x] .cursorrules configured
- [x] Added v2ray_box plugin

## In Progress
- [ ] Implement dynamic credential generation service (Dart)
- [ ] Write platform channel to pass credentials to Go binary

## To Do
- [ ] Build Xray-core for all platforms (Android, iOS, Windows, Linux, macOS)
- [ ] Build sing-box for all platforms
- [ ] Modify v2ray_box plugin to accept inbound credentials
- [ ] Add UI for subscription/profile management
- [ ] Implement engine switching
- [ ] Test vulnerability: attempt to connect to local SOCKS5 without password -> should fail
- [ ] Write integration tests

## Security Checklist
- [ ] No hardcoded credentials
- [ ] Local port bound only to 127.0.0.1
- [ ] Authentication mandatory
- [ ] Credentials regenerated per session
- [ ] Credentials cleared from memory after stop