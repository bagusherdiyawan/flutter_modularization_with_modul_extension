package com.pos.modularization;

/** Android dlopen ZIP syntax requires the literal !/ separator. */
public final class DeferredLibraryPath {
  private DeferredLibraryPath() {}
  public static String inApk(String apk, String abi, String library) {
    return apk + "!/lib/" + abi + "/" + library;
  }
}
