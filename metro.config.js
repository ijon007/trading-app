const path = require('path');
const { getDefaultConfig } = require('expo/metro-config');
const { withUniwindConfig } = require('uniwind/metro');

const config = getDefaultConfig(__dirname);

const uniwindConfig = withUniwindConfig(config, {
  cssEntryFile: './src/global.css',
  dtsFile: './src/uniwind-types.d.ts',
});

const resolveRequest = uniwindConfig.resolver.resolveRequest;
const webInputAccessoryView = path.join(
  __dirname,
  'node_modules/react-native-web/dist/exports/InputAccessoryView/index.js',
);

// Uniwind rewrites this iOS-only view to a web file the package does not ship.
uniwindConfig.resolver.resolveRequest = (context, moduleName, platform) => {
  try {
    return resolveRequest(context, moduleName, platform);
  } catch (error) {
    const isInputAccessory =
      moduleName === 'uniwind/components/InputAccessoryView' ||
      moduleName.endsWith('/InputAccessoryView') ||
      moduleName.endsWith('\\InputAccessoryView');

    if (platform === 'web' && isInputAccessory) {
      return { type: 'sourceFile', filePath: webInputAccessoryView };
    }

    throw error;
  }
};

module.exports = uniwindConfig;
