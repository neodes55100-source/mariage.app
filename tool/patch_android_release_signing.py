from pathlib import Path

path = Path('android/app/build.gradle.kts')
text = path.read_text()

imports = '''import java.util.Properties
import java.io.FileInputStream

'''
if 'import java.util.Properties' not in text:
    text = imports + text

props = '''val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

'''
if 'val keystoreProperties = Properties()' not in text:
    marker = 'android {\n'
    text = text.replace(marker, props + marker, 1)

signing = '''    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

'''
if 'create("release")' not in text:
    marker = '    buildTypes {\n'
    text = text.replace(marker, signing + marker, 1)

text = text.replace(
    'signingConfig = signingConfigs.getByName("debug")',
    'signingConfig = signingConfigs.getByName("release")',
)

path.write_text(text)
