// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.pos.modularization;

import io.flutter.embedding.engine.deferredcomponents.DeferredComponentManager;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.PackageManager.NameNotFoundException;
import android.content.res.AssetManager;
import android.os.Build;
import android.os.Bundle;
import android.util.SparseArray;
import android.util.SparseIntArray;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.google.android.play.core.splitinstall.SplitInstallException;
import com.google.android.play.core.splitinstall.SplitInstallManager;
import com.google.android.play.core.splitinstall.SplitInstallManagerFactory;
import com.google.android.play.core.splitinstall.SplitInstallRequest;
import com.google.android.play.core.splitinstall.SplitInstallSessionState;
import com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener;
import com.google.android.play.core.splitinstall.model.SplitInstallErrorCode;
import com.google.android.play.core.splitinstall.model.SplitInstallSessionStatus;
import io.flutter.Log;
import io.flutter.embedding.engine.FlutterJNI;
import io.flutter.embedding.engine.loader.ApplicationInfoLoader;
import io.flutter.embedding.engine.loader.FlutterApplicationInfo;
import io.flutter.embedding.engine.systemchannels.DeferredComponentChannel;
import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Queue;

/**
 * Flutter default implementation of DeferredComponentManager that downloads deferred component from
 * the Google Play store as a dynamic feature module.
 */
// Adapted from Flutter 3.32.8, commit edada7c56edf4a183c1735310e123c7f923584f1.
// Compiling against feature-delivery 2.1.0 binds startInstall and its listeners
// to GMS Tasks; the stock precompiled manager binds to legacy Play Core Tasks.
public class SmartPosDeferredComponentManager implements DeferredComponentManager {
  private static final String TAG = "SmartPosDeferredComponentManager";

  public static final String MAPPING_KEY =
      DeferredComponentManager.class.getName() + ".loadingUnitMapping";

  private @NonNull SplitInstallManager splitInstallManager;
  private @Nullable FlutterJNI flutterJNI;
  private @Nullable DeferredComponentChannel channel;
  private @NonNull Context context;
  private @NonNull FlutterApplicationInfo flutterApplicationInfo;
  // Each request to install a feature module gets a session ID. These maps associate
  // the session ID with the loading unit and component name that was requested.
  private @NonNull SparseArray<String> sessionIdToName;
  private @NonNull SparseIntArray sessionIdToLoadingUnitId;
  private @NonNull SparseArray<String> sessionIdToState;
  private @NonNull Map<String, Integer> nameToSessionId;

  protected @NonNull SparseArray<String> loadingUnitIdToComponentNames;
  protected @NonNull SparseArray<String> loadingUnitIdToSharedLibraryNames;

  private FeatureInstallStateUpdatedListener listener;
  private DeferredInstallCoordinator coordinator;

  private void checkpoint(String component, String state) {
    context.getSharedPreferences("module_diagnostics", Context.MODE_PRIVATE).edit()
        .putString("nativeComponent", component).putString("nativeState", state)
        .putLong("nativeTime", System.currentTimeMillis()).commit();
    Log.d(TAG, component + ": " + state);
  }


  private class FeatureInstallStateUpdatedListener implements SplitInstallStateUpdatedListener {
    @SuppressLint("DefaultLocale")
    public void onStateUpdate(@NonNull SplitInstallSessionState state) {
      int sessionId = state.sessionId();
      // Play can deliver an event before startInstall's success callback registers the session.
      if (sessionIdToName.get(sessionId) == null) {
        for (String module : state.moduleNames()) {
          if (coordinator.hasPending(module)) {
            sessionIdToName.put(sessionId, module);
            nameToSessionId.put(module, sessionId);
            break;
          }
        }
      }
      if (sessionIdToName.get(sessionId) != null) {
        checkpoint(sessionIdToName.get(sessionId), "playStatus=" + state.status()
            + "; session=" + sessionId + "; bytes=" + state.bytesDownloaded()
            + "/" + state.totalBytesToDownload());
        switch (state.status()) {
          case SplitInstallSessionStatus.FAILED:
            {
              Log.e(
                  TAG,
                  String.format(
                      "Module \"%s\" (sessionId %d) install failed with: %s",
                      sessionIdToName.get(sessionId), sessionId, state.errorCode()));
              coordinator.failed(sessionIdToName.get(sessionId),
                  "Module install failed with " + state.errorCode(), true);
              sessionIdToName.delete(sessionId);
              sessionIdToLoadingUnitId.delete(sessionId);
              sessionIdToState.put(sessionId, "failed");
              break;
            }
          case SplitInstallSessionStatus.INSTALLED:
            {
              Log.d(
                  TAG,
                  String.format(
                      "Module \"%s\" (sessionId %d) install successfully.",
                      sessionIdToName.get(sessionId), sessionId));
              coordinator.installed(sessionIdToName.get(sessionId));
              sessionIdToName.delete(sessionId);
              sessionIdToLoadingUnitId.delete(sessionId);
              sessionIdToState.put(sessionId, "installed");
              break;
            }
          case SplitInstallSessionStatus.CANCELED:
            {
              Log.d(
                  TAG,
                  String.format(
                      "Module \"%s\" (sessionId %d) install canceled.",
                      sessionIdToName.get(sessionId), sessionId));
              coordinator.failed(sessionIdToName.get(sessionId), "Module installation canceled", true);
              sessionIdToName.delete(sessionId);
              sessionIdToLoadingUnitId.delete(sessionId);
              sessionIdToState.put(sessionId, "cancelled");
              break;
            }
          case SplitInstallSessionStatus.CANCELING:
            {
              Log.d(
                  TAG,
                  String.format(
                      "Module \"%s\" (sessionId %d) install canceling.",
                      sessionIdToName.get(sessionId), sessionId));
              sessionIdToState.put(sessionId, "canceling");
              break;
            }
          case SplitInstallSessionStatus.PENDING:
            {
              Log.d(
                  TAG,
                  String.format(
                      "Module \"%s\" (sessionId %d) install pending.",
                      sessionIdToName.get(sessionId), sessionId));
              sessionIdToState.put(sessionId, "pending");
              break;
            }
          case SplitInstallSessionStatus.REQUIRES_USER_CONFIRMATION:
            {
              Log.d(
                  TAG,
                  String.format(
                      "Module \"%s\" (sessionId %d) install requires user confirmation.",
                      sessionIdToName.get(sessionId), sessionId));
              sessionIdToState.put(sessionId, "requiresUserConfirmation");
              break;
            }
          case SplitInstallSessionStatus.DOWNLOADING:
            {
              Log.d(
                  TAG,
                  String.format(
                      "Module \"%s\" (sessionId %d) downloading.",
                      sessionIdToName.get(sessionId), sessionId));
              sessionIdToState.put(sessionId, "downloading");
              break;
            }
          case SplitInstallSessionStatus.DOWNLOADED:
            {
              Log.d(
                  TAG,
                  String.format(
                      "Module \"%s\" (sessionId %d) downloaded.",
                      sessionIdToName.get(sessionId), sessionId));
              sessionIdToState.put(sessionId, "downloaded");
              break;
            }
          case SplitInstallSessionStatus.INSTALLING:
            {
              Log.d(
                  TAG,
                  String.format(
                      "Module \"%s\" (sessionId %d) installing.",
                      sessionIdToName.get(sessionId), sessionId));
              sessionIdToState.put(sessionId, "installing");
              break;
            }
          default:
            Log.d(TAG, "Unknown status: " + state.status());
        }
      }
    }
  }

  public SmartPosDeferredComponentManager(
      @NonNull Context context, @Nullable FlutterJNI flutterJNI) {
    this.context = context;
    this.flutterJNI = flutterJNI;
    this.flutterApplicationInfo = ApplicationInfoLoader.load(context);
    splitInstallManager = SplitInstallManagerFactory.create(context);
    listener = new FeatureInstallStateUpdatedListener();
    sessionIdToName = new SparseArray<>();
    sessionIdToLoadingUnitId = new SparseIntArray();
    sessionIdToState = new SparseArray<>();
    nameToSessionId = new HashMap<>();

    loadingUnitIdToComponentNames = new SparseArray<>();
    loadingUnitIdToSharedLibraryNames = new SparseArray<>();
    initLoadingUnitMappingToComponentNames();
    coordinator = new DeferredInstallCoordinator(new DeferredInstallCoordinator.Loader() {
      @Override public void load(int unit, String component) {
        checkpoint(component, "loadingAssets; unit=" + unit);
        loadAssets(unit, component);
        if (unit > 0) loadDartLibrary(unit, component);
        if (channel != null) channel.completeInstallSuccess(component);
      }
      @Override public void failed(int unit, String component, String message, boolean transientError) {
        checkpoint(component, "failed; " + message);
        if (flutterJNI != null) flutterJNI.deferredComponentInstallFailure(unit, message, transientError);
        if (channel != null) channel.completeInstallError(component, message);
      }
    });
    splitInstallManager.registerListener(listener);
  }

  public void setJNI(@NonNull FlutterJNI flutterJNI) {
    this.flutterJNI = flutterJNI;
  }

  private boolean verifyJNI() {
    if (flutterJNI == null) {
      Log.e(
          TAG,
          "No FlutterJNI provided. `setJNI` must be called on the DeferredComponentManager before attempting to load dart libraries or invoking with platform channels.");
      return false;
    }
    return true;
  }

  public void setDeferredComponentChannel(@NonNull DeferredComponentChannel channel) {
    this.channel = channel;
  }

  @NonNull
  private ApplicationInfo getApplicationInfo() {
    try {
      return context
          .getPackageManager()
          .getApplicationInfo(context.getPackageName(), PackageManager.GET_META_DATA);
    } catch (NameNotFoundException e) {
      throw new RuntimeException(e);
    }
  }

  // Obtain and parses the metadata string. An example encoded string is:
  //
  //    "2:component2,3:component3,4:component1:libcomponent4.so,5:"
  //
  // Where loading unit 2 is included in component2, loading unit 3 is
  // included in component3, and loading unit 4 is included in component1.
  // An optional third parameter can be added to indicate the name of
  // the shared library of the loading unit. Loading unit 5 maps to an empty
  // string, indicating it is included in the base module and no dynamic
  // feature modules need to be downloaded.
  private void initLoadingUnitMappingToComponentNames() {
    String mappingKey = DeferredComponentManager.class.getName() + ".loadingUnitMapping";
    ApplicationInfo applicationInfo = getApplicationInfo();
    if (applicationInfo != null) {
      Bundle metaData = applicationInfo.metaData;
      if (metaData != null) {
        String rawMappingString = metaData.getString(MAPPING_KEY, null);
        if (rawMappingString == null) {
          Log.e(
              TAG,
              "No loading unit to dynamic feature module name found. Ensure '"
                  + MAPPING_KEY
                  + "' is defined in the base module's AndroidManifest.");
          return;
        }
        if (rawMappingString.equals("")) {
          // Asset-only components, so no loading units to map.
          return;
        }
        for (String entry : rawMappingString.split(",")) {
          // Split with -1 param to include empty string following trailing ":"
          String[] splitEntry = entry.split(":", -1);
          int loadingUnitId = Integer.parseInt(splitEntry[0]);
          loadingUnitIdToComponentNames.put(loadingUnitId, splitEntry[1]);
          if (splitEntry.length > 2) {
            loadingUnitIdToSharedLibraryNames.put(loadingUnitId, splitEntry[2]);
          }
        }
      }
    }
  }

  public void installDeferredComponent(int loadingUnitId, @Nullable String componentName) {
    if (!verifyJNI()) return;
    String component = componentName != null ? componentName : loadingUnitIdToComponentNames.get(loadingUnitId);
    if (component == null) {
      flutterJNI.deferredComponentInstallFailure(loadingUnitId, "Missing loading-unit mapping", false);
      return;
    }
    if (component.isEmpty() && loadingUnitId > 0) {
      loadDartLibrary(loadingUnitId, component);
      return;
    }
    boolean installed = splitInstallManager.getInstalledModules().contains(component);
    checkpoint(component, "request; alreadyInstalled=" + installed + "; unit=" + loadingUnitId);
    coordinator.request(loadingUnitId, component, installed, () -> {
      SplitInstallRequest request = SplitInstallRequest.newBuilder().addModule(component).build();
      splitInstallManager.startInstall(request)
          .addOnSuccessListener(sessionId -> {
            if (coordinator.hasPending(component)) {
              sessionIdToName.put(sessionId, component);
              sessionIdToLoadingUnitId.put(sessionId, loadingUnitId);
              nameToSessionId.put(component, sessionId);
              sessionIdToState.put(sessionId, "Requested");
            }
            checkpoint(component, "accepted; session=" + sessionId);
            coordinator.accepted(component, sessionId,
                splitInstallManager.getInstalledModules().contains(component));
          })
          .addOnFailureListener(error -> {
            int code = error instanceof SplitInstallException
                ? ((SplitInstallException) error).getErrorCode() : 0;
            coordinator.failed(component, "Play install failed: " + code,
                code != SplitInstallErrorCode.MODULE_UNAVAILABLE);
          });
    });
  }

  @NonNull
  public String getDeferredComponentInstallState(
      int loadingUnitId, @Nullable String componentName) {
    String resolvedComponentName =
        componentName != null ? componentName : loadingUnitIdToComponentNames.get(loadingUnitId);
    if (resolvedComponentName == null) {
      Log.e(
          TAG, "Deferred component name was null and could not be resolved from loading unit id.");
      return "unknown";
    }
    if (!nameToSessionId.containsKey(resolvedComponentName)) {
      if (splitInstallManager.getInstalledModules().contains(resolvedComponentName)) {
        return "installedPendingLoad";
      }
      return "unknown";
    }
    int sessionId = nameToSessionId.get(resolvedComponentName);
    return sessionIdToState.get(sessionId);
  }

  public void loadAssets(int loadingUnitId, @NonNull String componentName) {
    if (!verifyJNI()) {
      return;
    }
    // Since android deferred component asset manager is handled through
    // context, neither parameter is used here. Assets are stored in
    // the apk's `assets` directory allowing them to be accessed by
    // Android's AssetManager directly.
    try {
      context = context.createPackageContext(context.getPackageName(), 0);

      AssetManager assetManager = context.getAssets();
      flutterJNI.updateJavaAssetManager(assetManager, flutterApplicationInfo.flutterAssetsDir);
    } catch (NameNotFoundException e) {
      throw new RuntimeException(e);
    }
  }

  public void loadDartLibrary(int loadingUnitId, @NonNull String componentName) {
    if (!verifyJNI()) {
      return;
    }
    // Loading unit must be specified and valid to load a dart library.
    if (loadingUnitId < 0) {
      return;
    }

    String aotSharedLibraryName = loadingUnitIdToSharedLibraryNames.get(loadingUnitId);
    if (aotSharedLibraryName == null) {
      // If the filename is not specified, we use dart's loading unit naming convention.
      aotSharedLibraryName =
          flutterApplicationInfo.aotSharedLibraryName + "-" + loadingUnitId + ".part.so";
    }

    // Possible values: armeabi, armeabi-v7a, arm64-v8a, x86, x86_64, mips, mips64
    String abi = Build.SUPPORTED_ABIS[0];
    String pathAbi = abi.replace("-", "_"); // abis are represented with underscores in paths.

    // TODO(garyq): Optimize this apk/file discovery process to use less i/o and be more
    // performant and robust.

    // Search directly in APKs first
    List<String> apkPaths = new ArrayList<>();
    // If not found in APKs, we check in extracted native libs for the lib directly.
    List<String> soPaths = new ArrayList<>();

    Queue<File> searchFiles = new LinkedList<>();
    // Downloaded modules are stored here
    searchFiles.add(context.getFilesDir());
    // The initial installed apks are provided by `sourceDirs` in ApplicationInfo.
    // The jniLibs we want are in the splits not the baseDir. These
    // APKs are only searched as a fallback, as base libs generally do not need
    // to be fully path referenced.
    String[] installedSplits = context.getApplicationInfo().splitSourceDirs;
    for (String path : installedSplits == null ? new String[0] : installedSplits) {
      searchFiles.add(new File(path));
    }

    while (!searchFiles.isEmpty()) {
      File file = searchFiles.remove();
      if (file != null && file.isDirectory() && file.listFiles() != null) {
        for (File f : file.listFiles()) {
          searchFiles.add(f);
        }
        continue;
      }
      String name = file.getName();
      // Special case for "split_config" since android base module non-master apks are
      // initially installed with the "split_config" prefix/name.
      if (name.endsWith(".apk")
          && (name.startsWith(componentName) || name.startsWith("split_" + componentName) || name.startsWith("split_config"))
          && name.contains(pathAbi)) {
        apkPaths.add(file.getAbsolutePath());
        continue;
      }
      if (name.equals(aotSharedLibraryName)) {
        soPaths.add(file.getAbsolutePath());
      }
    }

    List<String> searchPaths = new ArrayList<>();

    // Add the bare filename as the first search path. In some devices, the so
    // file can be dlopen-ed with just the file name.
    searchPaths.add(aotSharedLibraryName);

    for (String path : apkPaths) {
      searchPaths.add(DeferredLibraryPath.inApk(path, abi, aotSharedLibraryName));
    }
    for (String path : soPaths) {
      searchPaths.add(path);
    }

    checkpoint(componentName, "loadingDart; unit=" + loadingUnitId
        + "; candidates=" + searchPaths.toString());
    flutterJNI.loadDartDeferredLibrary(
        loadingUnitId, searchPaths.toArray(new String[searchPaths.size()]));
    checkpoint(componentName, "dartLibrarySubmitted; unit=" + loadingUnitId);
  }

  public boolean uninstallDeferredComponent(int loadingUnitId, @Nullable String componentName) {
    String resolvedComponentName =
        componentName != null ? componentName : loadingUnitIdToComponentNames.get(loadingUnitId);
    if (resolvedComponentName == null) {
      Log.e(
          TAG, "Deferred component name was null and could not be resolved from loading unit id.");
      return false;
    }
    List<String> modulesToUninstall = new ArrayList<>();
    modulesToUninstall.add(resolvedComponentName);
    splitInstallManager.deferredUninstall(modulesToUninstall);
    if (nameToSessionId.get(resolvedComponentName) != null) {
      sessionIdToState.delete(nameToSessionId.get(resolvedComponentName));
    }
    return true;
  }

  public void destroy() {
    splitInstallManager.unregisterListener(listener);
    channel = null;
    flutterJNI = null;
  }
}
