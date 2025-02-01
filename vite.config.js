import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  base: process.env.VERSION === 'easylogic' ? '/bg-css-gen-v2/' : '/bg-css-gen/',
  build: {
    outDir: process.env.VERSION === 'easylogic' ? '../apps.tomippe.jp/bg-css-gen-v2' : '../apps.tomippe.jp/bg-css-gen',
      emptyOutDir: true,
      rollupOptions: {
        output: { // entry chunk assets それぞれの書き出し名の指定
          entryFileNames: `assets/[name].js`,
          chunkFileNames: `assets/[name].js`,
          assetFileNames: `assets/[name].[ext]`,
        },
      },
  },
});
