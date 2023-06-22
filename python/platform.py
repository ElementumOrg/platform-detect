import os

from ctypes import c_int, cdll

platforms = {
  'android': [
    'arm64',
    'arm',
    'x64',
    'x86'
  ],
  'linux': [
    'arm64',
    'armv7',
    'armv6',
    'x64',
    'x86'
  ],
  'windows': [
    'x64',
    'x86'
  ],
  'darwin': [
    'x64'
  ]
}


# We try to detect a proper platform by loading different precompiled shared libraries.
# Proper library should return '42' as a result to a 'int test()' method call.
# We give preference to a 'higher' arch (x64 over x96, arm64 over armv7, etc).
def detect_platform():
    base_dir = os.path.join(os.path.dirname(__file__), "..")

    for system in platforms.keys():
        for arch in platforms.get(system):
            try:
                library_folder = os.path.join(base_dir, "libraries", system + "_" + arch)
                if os.path.exists(os.path.join(library_folder, "test.dll")):
                    library_path = os.path.join(library_folder, "test.dll")
                else:
                    library_path = os.path.join(library_folder, "test.so")

                # Try to load a library
                lib = cdll.LoadLibrary(library_path)

                # Make library call
                lib.test.restype = c_int
                result = lib.test()

                # Close the library, to avoid locking the file by a process
                if '.so' in library_path:
                    try:
                        lib.dlclose(lib._handle)
                    except:
                        pass
                else:
                    try:
                        from ctypes import windll
                        windll.kernel32.FreeLibrary(lib._handle)
                    except:
                        pass

                if result and result == 42:
                    return system + "-" + arch
            except:
                pass
    return None
