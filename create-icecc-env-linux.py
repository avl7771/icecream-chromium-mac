#!/usr/bin/env python

from __future__ import print_function

import contextlib
import os
import shutil
import sys
import tarfile
import tempfile
import urllib2

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

CDS_URL = os.environ.get('CDS_CLANG_BUCKET_OVERRIDE',
    'https://commondatastorage.googleapis.com/chromium-browser-clang')

@contextlib.contextmanager
def make_temp_directory():
    temp_dir = tempfile.mkdtemp()
    yield temp_dir
    shutil.rmtree(temp_dir)

def GetPlatformUrlPrefix(platform):
  if platform == 'win32' or platform == 'cygwin':
    return CDS_URL + '/Win/'
  if platform == 'darwin':
    return CDS_URL + '/Mac/'
  assert platform.startswith('linux')
  return CDS_URL + '/Linux_x64/'

def DownloadUrl(url, output_path):
  """Download url into output_path."""
  CHUNK_SIZE = 4096
  TOTAL_DOTS = 10
  num_retries = 3
  retry_wait_s = 5  # Doubled at each retry.

  with open(output_path, 'w') as output_file:
    while True:
      try:
        sys.stdout.write('Downloading %s ' % url)
        sys.stdout.flush()
        response = urllib2.urlopen(url)
        total_size = int(response.info().getheader('Content-Length').strip())
        bytes_done = 0
        dots_printed = 0
        while True:
          chunk = response.read(CHUNK_SIZE)
          if not chunk:
            break
          output_file.write(chunk)
          bytes_done += len(chunk)
          num_dots = TOTAL_DOTS * bytes_done / total_size
          sys.stderr.write('.' * (num_dots - dots_printed))
          sys.stderr.flush()
          dots_printed = num_dots
        if bytes_done != total_size:
          raise urllib2.URLError("only got %d of %d bytes" %
                                 (bytes_done, total_size))
        eprint(' Done.')
        return
      except urllib2.URLError as e:
        sys.stderr.write('\n')
        eprint(e)
        if num_retries == 0 or isinstance(e, urllib2.HTTPError) and e.code == 404:
          raise e
        num_retries -= 1
        eprint('Retrying in %d s ...' % retry_wait_s)
        time.sleep(retry_wait_s)
        retry_wait_s *= 2

def CreateIceccEnv(base_path, revision):
  with make_temp_directory() as temp_dir:
    icecc_env_path = os.path.join(temp_dir, 'icecc-env')
    icecc_env_pkg_path = 'clang-%s.tar.gz' % revision
    clang_prefix_path = os.path.join(icecc_env_path, 'usr')
    os.makedirs(clang_prefix_path)

    clang_pkg_filename = 'clang-%s.tgz' % revision
    clang_pkg_path = os.path.join(temp_dir, clang_pkg_filename)
    clang_pkg_url = GetPlatformUrlPrefix('linux') + clang_pkg_filename
    DownloadUrl(clang_pkg_url, clang_pkg_path)

    with tarfile.open(clang_pkg_path, 'r:gz') as t:
      t.extractall(clang_prefix_path)
    with tarfile.open(base_path, 'r:gz') as t:
      t.extractall(icecc_env_path)
    with tarfile.open(icecc_env_pkg_path, 'w:gz') as t:
      t.add(icecc_env_path, arcname='.')

    return icecc_env_pkg_path

def main():
  if len(sys.argv) < 3:
    eprint('Usage: %s [clang-icecc-base-linux.tar.gz] [revision]' % sys.argv[0])
    sys.exit(1)

  package = CreateIceccEnv(sys.argv[1], sys.argv[2])
  print(package)

if __name__ == "__main__":
  main()
