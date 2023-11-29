from socket import error as SocketError
from urllib.request import urlopen
from urllib import error
from http import client
import subprocess
import time

while True:
  try:
      r = urlopen("http://localhost/ping")
  except (error.HTTPError, error.URLError, client.RemoteDisconnected, SocketError):
      subprocess.run("sudo docker restart $(sudo docker ps -a| grep shs | awk '{print $1}')", shell=True)
  time.sleep(3)