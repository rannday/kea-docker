@echo off
setlocal

echo Stopping and removing all Docker containers...

FOR /F "tokens=*" %%i IN ('docker ps -aq') DO (
    docker rm -f %%i >nul 2>&1
)

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
