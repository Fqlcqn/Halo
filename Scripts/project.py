#!/usr/bin/env python3
"""Generate the single native Xcode build definition from source files. No binary input."""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def ident(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def quote(value): return '"' + value.replace('"', '\\"') + '"'
def generate():
    entries = []
    def add(name, body):
        entries.append(f'{ident(name)} = {{ {body} }};')
        return ident(name)
    children, source_builds, resource_builds = [], [], []
    for path in sorted((ROOT/'Sources').rglob('*')) + sorted((ROOT/'Resources').glob('*')) + [ROOT/'LICENSE']:
        if not path.is_file(): continue
        relative = str(path.relative_to(ROOT))
        types = {'.swift':'sourcecode.swift', '.m':'sourcecode.c.objc', '.h':'sourcecode.c.h', '.icns':'image.icns', '.applescript':'text', '.xcprivacy':'text.xml'}
        ref = add(relative, f'isa = PBXFileReference; lastKnownFileType = {quote(types.get(path.suffix, "text"))}; path = {quote(relative)}; sourceTree = SOURCE_ROOT;')
        children.append(ref)
        if path.suffix in ('.swift', '.m') or 'Resources' in path.parts or path.name == 'LICENSE':
            build = add(relative+'-build', f'isa = PBXBuildFile; fileRef = {ref};')
            (resource_builds if 'Resources' in path.parts or path.name == 'LICENSE' else source_builds).append(build)
    product = add('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = "Halo.app"; sourceTree = BUILT_PRODUCTS_DIR;')
    products = add('products', f'isa = PBXGroup; name = Products; children = ({product},); sourceTree = "<group>";')
    group = add('group', f'isa = PBXGroup; children = ({",".join(children+[products])},); sourceTree = "<group>";')
    sources = add('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(source_builds)},); runOnlyForDeploymentPostprocessing = 0;')
    resources = add('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(resource_builds)},); runOnlyForDeploymentPostprocessing = 0;')
    frameworks = add('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    configs = []
    for configuration in ('Debug','Release'):
        settings = {
            'PRODUCT_NAME':'Halo', 'PRODUCT_BUNDLE_IDENTIFIER':'com.maneesh.halo.production',
            'SDKROOT':'macosx', 'MACOSX_DEPLOYMENT_TARGET':'26.0', 'SWIFT_VERSION':'6.0', 'ALWAYS_SEARCH_USER_PATHS':'NO',
            'SWIFT_OBJC_BRIDGING_HEADER':'Sources/Halo-Bridging-Header.h',
            'HEADER_SEARCH_PATHS':'$(SRCROOT)/Sources/Input $(SRCROOT)/Sources/Settings',
            'INFOPLIST_FILE':'Configuration/Info.plist', 'CODE_SIGN_STYLE':'Manual', 'CODE_SIGN_IDENTITY':'-',
            'CODE_SIGN_ENTITLEMENTS':'Configuration/Direct.entitlements', 'ENABLE_HARDENED_RUNTIME':'YES',
            'ENABLE_APP_SANDBOX':'NO', 'CLANG_ENABLE_OBJC_ARC':'YES', 'SWIFT_STRICT_CONCURRENCY':'complete',
            'SWIFT_TREAT_WARNINGS_AS_ERRORS':'YES', 'GCC_TREAT_WARNINGS_AS_ERRORS':'YES',
            'GCC_WARN_UNUSED_VARIABLE':'YES', 'CLANG_WARN_DOCUMENTATION_COMMENTS':'YES',
            'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if configuration=='Debug' else '-O',
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if configuration=='Debug' else '',
            'DEBUG_INFORMATION_FORMAT':'dwarf' if configuration=='Debug' else 'dwarf-with-dsym',
            'CONFIGURATION_BUILD_DIR':'$(SRCROOT)/Build/$(CONFIGURATION)', 'ONLY_ACTIVE_ARCH':'YES' if configuration=='Debug' else 'NO',
            'OTHER_LDFLAGS':'-framework Carbon -framework ApplicationServices -framework QuartzCore',
            'COMBINE_HIDPI_IMAGES':'YES', 'LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks',
        }
        configs.append(add(configuration, f'isa = XCBuildConfiguration; name = {configuration}; buildSettings = {{'+''.join(f'{key} = {quote(value)};' for key,value in settings.items())+'};'))
    configuration_list = add('configurations', f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    target = add('target', f'isa = PBXNativeTarget; buildConfigurationList = {configuration_list}; buildPhases = ({sources},{frameworks},{resources},); buildRules = (); dependencies = (); name = Halo; productName = "Halo"; productReference = {product}; productType = "com.apple.product-type.application";')
    project = add('project', f'isa = PBXProject; attributes = {{LastUpgradeCheck = 2700;}}; buildConfigurationList = {configuration_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,Base,); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
    folder = ROOT/'Halo.xcodeproj'
    folder.mkdir(exist_ok=True)
    (folder/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(entries)+f'\n}}; rootObject = {project}; }}\n')
    schemes = folder/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
    ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Halo.app" BlueprintName="Halo" ReferencedContainer="container:Halo.xcodeproj"/>'
    (schemes/'Halo.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
if __name__ == '__main__': generate()
