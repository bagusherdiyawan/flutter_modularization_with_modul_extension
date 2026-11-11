#!/usr/bin/env python3
"""Run Android-independent install callback regression tests with the real coordinator."""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
compiler = ['javac'] if shutil.which('javac') else ['java', '-m', 'jdk.compiler/com.sun.tools.javac.Main']
with tempfile.TemporaryDirectory(prefix='smartpos-install-tests-') as output:
    subprocess.run([
        *compiler, '-source', '17', '-target', '17', '-nowarn', '-d', output,
        str(root / 'android/app/src/main/modernPlay/com/pos/modularization/DeferredInstallCoordinator.java'),
        str(root / 'android/app/src/main/modernPlay/com/pos/modularization/DeferredLibraryPath.java'),
        str(root / 'tool/native_tests/DeferredInstallCoordinatorTest.java'),
    ], check=True)
    subprocess.run(['java', '-cp', output, 'com.pos.modularization.DeferredInstallCoordinatorTest'], check=True)
