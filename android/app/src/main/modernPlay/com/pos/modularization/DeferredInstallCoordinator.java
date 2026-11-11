package com.pos.modularization;

import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;

/** Coordinates Play callbacks without depending on Android, so race cases can be regression tested. */
public final class DeferredInstallCoordinator {
  public interface Loader {
    void load(int unit, String component);
    void failed(int unit, String component, String message, boolean transientError);
  }

  private final Map<String, Set<Integer>> pending = new HashMap<>();
  private final Loader loader;

  public DeferredInstallCoordinator(Loader loader) { this.loader = loader; }

  public boolean hasPending(String component) { return pending.containsKey(component); }

  public void request(int unit, String component, boolean installed, Runnable submit) {
    boolean first = !pending.containsKey(component);
    pending.computeIfAbsent(component, key -> new LinkedHashSet<>()).add(unit);
    if (installed) {
      installed(component);
    } else if (first) {
      // Pending registration must precede submit: INSTALLED may beat the success callback.
      try {
        submit.run();
      } catch (RuntimeException | LinkageError error) {
        failed(component, "Requesting module failed: " + error.getClass().getSimpleName(), true);
      }
    }
  }

  public void accepted(String component, int sessionId, boolean nowInstalled) {
    // Session 0 means Play needs no installation. A new INSTALLED event is not guaranteed.
    if (sessionId == 0 || nowInstalled) installed(component);
  }

  public void installed(String component) {
    Set<Integer> units = pending.remove(component);
    if (units == null) return;
    for (int unit : units) {
      try {
        loader.load(unit, component);
      } catch (RuntimeException | LinkageError error) {
        loader.failed(unit, component, "Loading installed module failed: " + error.getClass().getSimpleName(), true);
      }
    }
  }

  public void failed(String component, String message, boolean transientError) {
    Set<Integer> units = pending.remove(component);
    if (units == null) return;
    for (int unit : units) loader.failed(unit, component, message, transientError);
  }
}
