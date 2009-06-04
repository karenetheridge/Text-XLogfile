# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name           'Text-XLogfile';
all_from       'lib/Text/XLogfile.pm';
githubmeta;

requires       'Carp';
requires       'Exporter';

build_requires 'Test::More';
build_requires 'File::Temp';

auto_install;
WriteAll;

