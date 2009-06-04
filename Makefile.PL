# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name           'Text-XLogfile';
all_from       'lib/Text/XLogfile.pm';
githubmeta;

build_requires 'File::Temp';

auto_install;
WriteAll;

