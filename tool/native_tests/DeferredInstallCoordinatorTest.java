package com.pos.modularization;

import java.util.ArrayList;
import java.util.List;

/** Executable JVM regression tests; uses the production coordinator, not a reimplementation. */
public final class DeferredInstallCoordinatorTest {
  static final class Fixture implements DeferredInstallCoordinator.Loader {
    final List<Integer> loaded = new ArrayList<>();
    final List<Integer> failed = new ArrayList<>();
    final DeferredInstallCoordinator coordinator = new DeferredInstallCoordinator(this);
    int submissions;
    boolean throwOnLoad;
    @Override public void load(int unit, String component) {
      if (throwOnLoad) throw new IllegalStateException("load error");
      loaded.add(unit);
    }
    @Override public void failed(int unit, String component, String message, boolean retry) {
      failed.add(unit);
    }
    void submit() { submissions++; }
  }
  static void check(boolean ok, String message) {
    if (!ok) throw new AssertionError(message);
  }
  public static void main(String[] args) throws Exception {
    Fixture f = new Fixture();
    f.coordinator.request(2, "edc", true, f::submit);
    check(f.loaded.equals(List.of(2)) && f.submissions == 0, "Installed split must load without new install/event");

    f = new Fixture();
    f.coordinator.request(3, "pulsa", false, f::submit);
    f.coordinator.accepted("pulsa", 0, false);
    check(f.loaded.equals(List.of(3)), "Session zero must load without INSTALLED event");

    f = new Fixture();
    Fixture early = f;
    f.coordinator.request(2, "edc", false, () -> {
      early.submit();
      early.coordinator.installed("edc"); // INSTALLED before request acknowledgement
      early.coordinator.accepted("edc", 42, true);
    });
    check(f.loaded.equals(List.of(2)) && !f.coordinator.hasPending("edc"), "Early INSTALLED must resolve exactly once");

    f = new Fixture();
    f.coordinator.request(2, "edc", false, f::submit);
    f.coordinator.accepted("edc", 42, false);
    check(f.loaded.isEmpty(), "Accepted request is not installation completion");
    f.coordinator.installed("edc");
    f.coordinator.installed("edc");
    check(f.loaded.equals(List.of(2)), "Duplicate events must not load twice");

    f = new Fixture();
    f.coordinator.request(2, "edc", false, f::submit);
    f.coordinator.accepted("edc", 42, true);
    check(f.loaded.equals(List.of(2)), "Already installed by acknowledgement time must load");

    f = new Fixture();
    f.coordinator.request(2, "edc", false, f::submit);
    f.coordinator.request(4, "edc", false, f::submit);
    f.coordinator.installed("edc");
    check(f.submissions == 1 && f.loaded.equals(List.of(2, 4)), "Concurrent units share one install but all finish");

    f = new Fixture();
    f.coordinator.request(3, "pulsa", false, f::submit);
    f.coordinator.failed("pulsa", "cancelled", true);
    f.coordinator.request(3, "pulsa", true, f::submit);
    check(f.failed.equals(List.of(3)) && f.loaded.equals(List.of(3)), "Failure clears pending and allows retry");

    f = new Fixture();
    f.coordinator.request(2, "edc", false, () -> { throw new IllegalStateException("request error"); });
    check(f.failed.equals(List.of(2)), "Synchronous request errors must resolve as failures");

    f = new Fixture();
    f.throwOnLoad = true;
    f.coordinator.request(2, "edc", true, f::submit);
    check(f.failed.equals(List.of(2)), "Loader errors must not leave a pending future");
    java.nio.file.Path apk = java.nio.file.Files.createTempFile("smartpos-split-", ".apk");
    try {
      try (java.util.zip.ZipOutputStream zip = new java.util.zip.ZipOutputStream(java.nio.file.Files.newOutputStream(apk))) {
        zip.putNextEntry(new java.util.zip.ZipEntry("lib/arm64-v8a/libapp.so-3.part.so"));
        zip.write(new byte[] {1, 2, 3});
        zip.closeEntry();
      }
      String libraryPath = DeferredLibraryPath.inApk(apk.toString(), "arm64-v8a", "libapp.so-3.part.so");
      int separator = libraryPath.indexOf("!/");
      check(separator > 0, "Android ZIP loader requires !/ separator");
      try (java.util.zip.ZipFile zip = new java.util.zip.ZipFile(libraryPath.substring(0, separator))) {
        check(zip.getEntry(libraryPath.substring(separator + 2)) != null, "APK path must resolve the actual deferred library entry");
      }
    } finally { java.nio.file.Files.deleteIfExists(apk); }
    System.out.println("PASS: 9 callback scenarios and 1 APK library path regression.");
  }
}
