@echo off
setlocal

echo Stopping and removing kea-custom...

docker rm -f kea-custom 2>nul

echo.
echo Running Kea Docker container on Windows...

docker run --rm -it ^
  --cap-add=NET_ADMIN ^
  -p 6767:67/udp ^
  -p 6547:547/udp ^
  -p 8001:8000 ^
  -v "%cd%\config:/etc/kea:ro" ^
  -v "%cd%\logs:/var/log/kea" ^
  kea-custom

endlocal
