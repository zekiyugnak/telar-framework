#!/usr/bin/env node
/**
 * Cross-platform mobile app build helper
 * Detects platform and provides unified build commands
 */

const { execSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

class MobileBuildHelper {
  constructor() {
    this.platform = this.detectPlatform();
    this.config = this.loadConfig();
  }

  detectPlatform() {
    if (fs.existsSync('pubspec.yaml')) {
      return 'flutter';
    }
    if (fs.existsSync('package.json')) {
      const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
      if (pkg.dependencies?.['react-native']) {
        return 'react-native';
      }
      if (pkg.dependencies?.['expo']) {
        return 'expo';
      }
    }
    return 'unknown';
  }

  loadConfig() {
    const configPath = '.mobile-build.json';
    if (fs.existsSync(configPath)) {
      return JSON.parse(fs.readFileSync(configPath, 'utf8'));
    }
    return {
      ios: { scheme: null, configuration: 'Release' },
      android: { flavor: null, buildType: 'release' }
    };
  }

  run(command, options = {}) {
    console.log(`\n▶ ${command}\n`);
    try {
      execSync(command, { stdio: 'inherit', ...options });
      return true;
    } catch (e) {
      console.error(`\n❌ Command failed: ${command}`);
      return false;
    }
  }

  // Flutter builds
  flutterBuildIos(release = true) {
    const mode = release ? '--release' : '--debug';
    return this.run(`flutter build ios ${mode}`);
  }

  flutterBuildAndroid(release = true, aab = true) {
    const mode = release ? '--release' : '--debug';
    const type = aab ? 'appbundle' : 'apk';
    return this.run(`flutter build ${type} ${mode}`);
  }

  flutterBuildWeb() {
    return this.run('flutter build web --release');
  }

  // React Native builds
  rnBuildIos(release = true) {
    const config = release ? 'Release' : 'Debug';
    const scheme = this.config.ios.scheme || 'App';
    return this.run(
      `cd ios && xcodebuild -workspace *.xcworkspace -scheme ${scheme} -configuration ${config} -sdk iphoneos archive`
    );
  }

  rnBuildAndroid(release = true) {
    const task = release ? 'assembleRelease' : 'assembleDebug';
    const flavor = this.config.android.flavor;
    const fullTask = flavor ? `assemble${flavor}${release ? 'Release' : 'Debug'}` : task;
    return this.run(`cd android && ./gradlew ${fullTask}`);
  }

  // Expo builds
  expoBuildIos() {
    return this.run('eas build --platform ios');
  }

  expoBuildAndroid() {
    return this.run('eas build --platform android');
  }

  // Clean commands
  clean() {
    console.log('🧹 Cleaning build artifacts...\n');

    switch (this.platform) {
      case 'flutter':
        this.run('flutter clean');
        if (fs.existsSync('ios')) {
          this.run('cd ios && rm -rf Pods Podfile.lock');
        }
        break;

      case 'react-native':
        this.run('rm -rf node_modules');
        this.run('npm install');
        if (fs.existsSync('ios')) {
          this.run('cd ios && rm -rf Pods Podfile.lock build');
          this.run('cd ios && pod install');
        }
        if (fs.existsSync('android')) {
          this.run('cd android && ./gradlew clean');
        }
        break;

      case 'expo':
        this.run('expo prebuild --clean');
        break;
    }

    console.log('\n✅ Clean complete');
  }

  // Unified build command
  build(target, release = true) {
    console.log(`\n📱 Building for ${target} (${release ? 'release' : 'debug'})...\n`);
    console.log(`Platform: ${this.platform}`);

    switch (this.platform) {
      case 'flutter':
        if (target === 'ios') return this.flutterBuildIos(release);
        if (target === 'android') return this.flutterBuildAndroid(release);
        if (target === 'web') return this.flutterBuildWeb();
        break;

      case 'react-native':
        if (target === 'ios') return this.rnBuildIos(release);
        if (target === 'android') return this.rnBuildAndroid(release);
        break;

      case 'expo':
        if (target === 'ios') return this.expoBuildIos();
        if (target === 'android') return this.expoBuildAndroid();
        break;

      default:
        console.error('Unknown platform');
        return false;
    }
  }

  printHelp() {
    console.log(`
📱 Mobile Build Helper
=====================

Usage: node build-helper.js <command> [options]

Commands:
  build ios [--debug]     Build iOS app
  build android [--debug] Build Android app
  build web               Build web app (Flutter only)
  clean                   Clean build artifacts
  info                    Show project info

Detected platform: ${this.platform}
    `);
  }

  printInfo() {
    console.log(`
📱 Project Information
=====================

Platform: ${this.platform}
`);

    if (this.platform === 'flutter') {
      this.run('flutter --version', { stdio: 'inherit' });
      console.log('\nDependencies:');
      this.run('flutter pub deps --style=compact | head -20', { stdio: 'inherit' });
    }

    if (this.platform === 'react-native' || this.platform === 'expo') {
      const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
      console.log(`React Native: ${pkg.dependencies['react-native'] || 'N/A'}`);
      console.log(`React: ${pkg.dependencies['react'] || 'N/A'}`);
      if (pkg.dependencies['expo']) {
        console.log(`Expo: ${pkg.dependencies['expo']}`);
      }
    }
  }
}

// CLI handling
const args = process.argv.slice(2);
const helper = new MobileBuildHelper();

if (args.length === 0 || args[0] === 'help') {
  helper.printHelp();
} else if (args[0] === 'build') {
  const target = args[1];
  const release = !args.includes('--debug');
  helper.build(target, release);
} else if (args[0] === 'clean') {
  helper.clean();
} else if (args[0] === 'info') {
  helper.printInfo();
} else {
  console.error(`Unknown command: ${args[0]}`);
  helper.printHelp();
}

module.exports = MobileBuildHelper;
