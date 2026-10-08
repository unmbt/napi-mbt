function visualStudioGenerator(instance, capabilities) {
  const major = instance.installationVersion.split('.')[0];
  // VS 2026 reports catalog.productLineVersion as "18", not a year.
  // Use CMake's own generator name rather than constructing one from it.
  const generator = capabilities.generators.find(item => item.name.startsWith(`Visual Studio ${major} `));
  if (!generator) {
    throw new Error(`CMake has no generator for Visual Studio ${major}; update CMake to support the installed Visual Studio`);
  }
  return generator.name;
}

module.exports = visualStudioGenerator;
