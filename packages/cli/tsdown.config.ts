import { defineConfig } from 'tsdown'

export default defineConfig({
  entry: ['./src/generate.js', './src/index.js', './src/cli.js'],
  format: ['esm', 'cjs'],
  clean: true,
  outDir: 'dist'
})
