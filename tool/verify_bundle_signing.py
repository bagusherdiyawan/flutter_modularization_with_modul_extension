#!/usr/bin/env python3
"""Verify AAB JAR signature and match its signer to the expected public upload certificate."""
import argparse
import re
import shutil
import subprocess


def fingerprint(arguments):
    result = subprocess.run(
        ['keytool', '-J-Duser.language=en', '-printcert', *arguments],
        capture_output=True, text=True, check=True,
    )
    values = re.findall(r'SHA256:\s*([0-9A-Fa-f:]+)', result.stdout)
    if len(values) != 1:
        raise SystemExit('Expected exactly one signer certificate.')
    return values[0].replace(':', '').lower()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', required=True)
    parser.add_argument('--certificate', required=True)
    args = parser.parse_args()
    signer = ['jarsigner'] if shutil.which('jarsigner') else ['java', '-m', 'jdk.jartool/sun.security.tools.jarsigner.Main']
    result = subprocess.run([*signer, '-verify', args.bundle], capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit('AAB signature verification failed.')
    if fingerprint(['-jarfile', args.bundle]) != fingerprint(['-file', args.certificate]):
        raise SystemExit('AAB signer does not match the upload certificate.')
    print('PASS: AAB signature verified and signer matches the upload certificate.')


if __name__ == '__main__':
    main()
