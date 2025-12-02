const { withXcodeProject, withEntitlementsPlist } = require('@expo/config-plugins');
const xcode = require('xcode');
const fs = require('fs');
const path = require('path');

const WIDGET_TARGET_NAME = 'ShiftWidget';
const APP_GROUP_IDENTIFIER = 'group.com.ghichu.widgetdata';

const withWidget = (config) => {
  // 1. Thêm App Group vào App Chính
  config = withEntitlementsPlist(config, (config) => {
    config.modResults['com.apple.security.application-groups'] = [APP_GROUP_IDENTIFIER];
    return config;
  });

  // 2. Can thiệp vào file Project Xcode
  config = withXcodeProject(config, async (config) => {
    const projectPath = config.modResults.filepath;
    const project = xcode.project(projectPath);

    project.parse(async function (err) {
      if (err) {
        console.error('Error parsing project:', err);
        return;
      }

      // --- COPY FILES ---
      // Copy nguyên liệu từ thư mục widget vào ios/ShiftWidget
      const widgetSourceDir = path.join(__dirname, '../widget');
      const widgetDestDir = path.join(path.dirname(projectPath), WIDGET_TARGET_NAME);

      if (!fs.existsSync(widgetDestDir)) {
        fs.mkdirSync(widgetDestDir, { recursive: true });
      }

      ['ShiftWidget.swift', 'Info.plist'].forEach((file) => {
        const src = path.join(widgetSourceDir, file);
        const dest = path.join(widgetDestDir, file);
        if (fs.existsSync(src)) {
            fs.copyFileSync(src, dest);
        }
      });

      // --- TẠO TARGET (Dùng hàm có sẵn để tránh lỗi) ---
      // Hàm addTarget này tự động tạo NativeTarget, ConfigurationList, và Dependencies
      const target = project.addTarget(WIDGET_TARGET_NAME, 'app_extension', WIDGET_TARGET_NAME);

      // --- THÊM FILE VÀO PROJECT ---
      // Thêm file Swift vào target mới tạo (nó tự add vào Sources Build Phase)
      project.addSourceFile(`${WIDGET_TARGET_NAME}/ShiftWidget.swift`, { target: target.uuid }, project.getFirstTarget().uuid);
      
      // Thêm file Info.plist (chỉ add vào project, không add vào build phase)
      project.addFile(`${WIDGET_TARGET_NAME}/Info.plist`);

      // --- TẠO ENTITLEMENTS (Cho App Group) ---
      const entitlementsContent = `
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>com.apple.security.application-groups</key>
            <array>
                <string>${APP_GROUP_IDENTIFIER}</string>
            </array>
        </dict>
        </plist>
      `;
      const entitlementsPath = path.join(widgetDestDir, `${WIDGET_TARGET_NAME}.entitlements`);
      fs.writeFileSync(entitlementsPath, entitlementsContent.trim());
      
      // Thêm file entitlements vào project
      project.addFile(`${WIDGET_TARGET_NAME}/${WIDGET_TARGET_NAME}.entitlements`);

      // --- CẬP NHẬT BUILD SETTINGS (Quan trọng) ---
      // Vì addTarget tạo cấu hình mặc định, ta phải ghi đè cấu hình cho Widget
      const configurations = project.pbxXCBuildConfigurationSection();
      const widgetBundleId = `${config.ios.bundleIdentifier}.${WIDGET_TARGET_NAME}`;

      for (const key in configurations) {
        if (typeof configurations[key] === 'object') {
          const buildSettings = configurations[key].buildSettings;
          
          // Chỉ sửa cấu hình của Target Widget (dựa trên Product Name)
          if (buildSettings['PRODUCT_NAME'] === `"${WIDGET_TARGET_NAME}"` || buildSettings['PRODUCT_NAME'] === WIDGET_TARGET_NAME) {
            
            buildSettings['INFOPLIST_FILE'] = `${WIDGET_TARGET_NAME}/Info.plist`;
            buildSettings['PRODUCT_BUNDLE_IDENTIFIER'] = widgetBundleId;
            buildSettings['SWIFT_VERSION'] = '5.0';
            buildSettings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0';
            buildSettings['TARGETED_DEVICE_FAMILY'] = '"1"'; // Chỉ iPhone
            buildSettings['SKIP_INSTALL'] = 'YES';
            buildSettings['CODE_SIGN_ENTITLEMENTS'] = `${WIDGET_TARGET_NAME}/${WIDGET_TARGET_NAME}.entitlements`;
            buildSettings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon';
            
            // Cấu hình để không cần chứng chỉ (Cho Github Actions)
            buildSettings['CODE_SIGNING_ALLOWED'] = 'NO';
            buildSettings['CODE_SIGNING_REQUIRED'] = 'NO';
            buildSettings['CODE_SIGN_IDENTITY'] = '""';
            buildSettings['DEVELOPMENT_TEAM'] = '""';
          }
        }
      }

      // Lưu lại Project
      fs.writeFileSync(projectPath, project.writeSync());
    });

    return config;
  });

  return config;
};

module.exports = withWidget;