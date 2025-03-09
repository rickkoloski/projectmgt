import { defineConfig } from 'vite'
import { fileURLToPath, URL } from 'node:url'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./app/javascript', import.meta.url))
    }
  },
  build: {
    outDir: 'app/assets/builds',
    emptyOutDir: true,
    rollupOptions: {
      input: 'app/javascript/application.js',
      output: {
        entryFileNames: '[name].js',
        chunkFileNames: '[name]-[hash].js',
        assetFileNames: '[name].[ext]'
      }
    }
  }
})