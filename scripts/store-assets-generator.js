#!/usr/bin/env node
/**
 * App Store / Play Store asset generator
 * Generates required screenshots, icons, and promotional images
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Required asset sizes
const ASSET_SPECS = {
  ios: {
    icon: [
      { size: 1024, name: 'AppIcon-1024' }, // App Store
      { size: 180, name: 'AppIcon-180' },   // iPhone @3x
      { size: 167, name: 'AppIcon-167' },   // iPad Pro
      { size: 152, name: 'AppIcon-152' },   // iPad @2x
      { size: 120, name: 'AppIcon-120' },   // iPhone @2x
    ],
    screenshots: [
      { width: 1290, height: 2796, name: 'iPhone-6.7' },  // iPhone 15 Pro Max
      { width: 1179, height: 2556, name: 'iPhone-6.1' },  // iPhone 15 Pro
      { width: 1242, height: 2688, name: 'iPhone-6.5' },  // iPhone 11 Pro Max
      { width: 2048, height: 2732, name: 'iPad-12.9' },   // iPad Pro 12.9"
    ]
  },
  android: {
    icon: [
      { size: 512, name: 'playstore-icon' },
      { size: 192, name: 'ic_launcher-xxxhdpi' },
      { size: 144, name: 'ic_launcher-xxhdpi' },
      { size: 96, name: 'ic_launcher-xhdpi' },
      { size: 72, name: 'ic_launcher-hdpi' },
      { size: 48, name: 'ic_launcher-mdpi' },
    ],
    featureGraphic: { width: 1024, height: 500, name: 'feature-graphic' },
    screenshots: [
      { width: 1080, height: 1920, name: 'phone' },
      { width: 1600, height: 2560, name: 'tablet-7' },
      { width: 2048, height: 2732, name: 'tablet-10' },
    ]
  }
};

class StoreAssetGenerator {
  constructor(outputDir = 'store-assets') {
    this.outputDir = outputDir;
    this.checkDependencies();
  }

  checkDependencies() {
    try {
      execSync('which convert', { stdio: 'pipe' });
    } catch {
      console.error('❌ ImageMagick not found. Install with: brew install imagemagick');
      process.exit(1);
    }
  }

  ensureDir(dir) {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  generateIcons(sourceIcon) {
    console.log('\n🎨 Generating app icons...\n');

    if (!fs.existsSync(sourceIcon)) {
      console.error(`❌ Source icon not found: ${sourceIcon}`);
      console.log('Please provide a 1024x1024 PNG icon');
      return false;
    }

    // iOS icons
    const iosDir = path.join(this.outputDir, 'ios', 'icons');
    this.ensureDir(iosDir);

    for (const spec of ASSET_SPECS.ios.icon) {
      const output = path.join(iosDir, `${spec.name}.png`);
      execSync(`convert "${sourceIcon}" -resize ${spec.size}x${spec.size} "${output}"`);
      console.log(`  ✓ ${spec.name}.png (${spec.size}x${spec.size})`);
    }

    // Android icons
    const androidDir = path.join(this.outputDir, 'android', 'icons');
    this.ensureDir(androidDir);

    for (const spec of ASSET_SPECS.android.icon) {
      const output = path.join(androidDir, `${spec.name}.png`);
      execSync(`convert "${sourceIcon}" -resize ${spec.size}x${spec.size} "${output}"`);
      console.log(`  ✓ ${spec.name}.png (${spec.size}x${spec.size})`);
    }

    console.log('\n✅ Icons generated successfully');
    return true;
  }

  generateScreenshotTemplates() {
    console.log('\n📸 Generating screenshot templates...\n');

    // iOS screenshots
    const iosDir = path.join(this.outputDir, 'ios', 'screenshots');
    this.ensureDir(iosDir);

    for (const spec of ASSET_SPECS.ios.screenshots) {
      const output = path.join(iosDir, `${spec.name}-template.png`);
      execSync(
        `convert -size ${spec.width}x${spec.height} xc:#f0f0f0 ` +
        `-gravity center -pointsize 48 -fill '#666' ` +
        `-annotate 0 '${spec.name}\\n${spec.width}x${spec.height}' "${output}"`
      );
      console.log(`  ✓ ${spec.name}-template.png`);
    }

    // Android screenshots
    const androidDir = path.join(this.outputDir, 'android', 'screenshots');
    this.ensureDir(androidDir);

    for (const spec of ASSET_SPECS.android.screenshots) {
      const output = path.join(androidDir, `${spec.name}-template.png`);
      execSync(
        `convert -size ${spec.width}x${spec.height} xc:#f0f0f0 ` +
        `-gravity center -pointsize 48 -fill '#666' ` +
        `-annotate 0 '${spec.name}\\n${spec.width}x${spec.height}' "${output}"`
      );
      console.log(`  ✓ ${spec.name}-template.png`);
    }

    // Android feature graphic
    const fg = ASSET_SPECS.android.featureGraphic;
    const fgOutput = path.join(androidDir, `${fg.name}-template.png`);
    execSync(
      `convert -size ${fg.width}x${fg.height} xc:#4A90D9 ` +
      `-gravity center -pointsize 72 -fill white ` +
      `-annotate 0 'Feature Graphic\\n${fg.width}x${fg.height}' "${fgOutput}"`
    );
    console.log(`  ✓ ${fg.name}-template.png`);

    console.log('\n✅ Screenshot templates generated');
    console.log('   Replace templates with actual screenshots');
  }

  generateChecklist() {
    const checklist = `
# Store Asset Checklist

## iOS App Store

### Required Assets
- [ ] App Icon (1024x1024)
- [ ] Screenshots:
  - [ ] iPhone 6.7" (1290x2796) - Required
  - [ ] iPhone 6.1" (1179x2556) - Required for all iPhones
  - [ ] iPad 12.9" (2048x2732) - Required if supporting iPad
- [ ] App Preview Video (optional, 15-30 seconds)

### App Store Connect
- [ ] App Name (30 characters max)
- [ ] Subtitle (30 characters max)
- [ ] Description (4000 characters max)
- [ ] Keywords (100 characters max)
- [ ] Privacy Policy URL
- [ ] Support URL

## Google Play Store

### Required Assets
- [ ] App Icon (512x512)
- [ ] Feature Graphic (1024x500)
- [ ] Screenshots:
  - [ ] Phone (1080x1920) - 2-8 required
  - [ ] 7" Tablet (optional)
  - [ ] 10" Tablet (optional)
- [ ] Promo Video (YouTube URL, optional)

### Play Console
- [ ] Title (50 characters max)
- [ ] Short Description (80 characters max)
- [ ] Full Description (4000 characters max)
- [ ] Privacy Policy URL
- [ ] Content Rating Questionnaire
- [ ] Data Safety Form

## Generated Assets Location
- iOS: ${this.outputDir}/ios/
- Android: ${this.outputDir}/android/
`;

    const checklistPath = path.join(this.outputDir, 'CHECKLIST.md');
    fs.writeFileSync(checklistPath, checklist);
    console.log(`\n📋 Checklist saved to ${checklistPath}`);
  }

  run(sourceIcon) {
    console.log('╔════════════════════════════════════╗');
    console.log('║   Store Asset Generator            ║');
    console.log('╚════════════════════════════════════╝');

    this.ensureDir(this.outputDir);

    if (sourceIcon) {
      this.generateIcons(sourceIcon);
    } else {
      console.log('\n⚠️  No source icon provided');
      console.log('   Run with: node store-assets-generator.js path/to/icon.png');
    }

    this.generateScreenshotTemplates();
    this.generateChecklist();

    console.log(`\n✅ All assets generated in: ${this.outputDir}/`);
  }
}

// CLI
const args = process.argv.slice(2);
const generator = new StoreAssetGenerator();
generator.run(args[0]);

module.exports = StoreAssetGenerator;
