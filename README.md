# RS — Daily RSS XML mirrors

本仓库每日镜像局域网 RSS 源到 GitHub Pages，便于公网读取。

## Pages

- 首页: https://kddy918.github.io/RS/
- Feed 1: https://kddy918.github.io/RS/feeds/t66y-7.xml
- Feed 2: https://kddy918.github.io/RS/feeds/t66y-20.xml

## 更新方式

主路径：本机 Windows 计划任务每日运行 `scripts/update-feeds.ps1`（因源在局域网 `192.168.60.x`，GitHub Actions 云端通常无法访问）。

备用：`.github/workflows/update-feeds.yml` 仅在 runner 能访问源时有效。
