/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.{html,ts}'],
  theme: {
    extend: {
      colors: {
        ink: '#0E0E10',
        surface: '#16161A',
        raised: '#1D1D22',
        line: '#2A2A31',
        accent: { DEFAULT: '#CBA35C', soft: '#E3C68F', ink: '#17130A' },
        body: '#F2F1EE',
        muted: '#9A9AA3',
        faint: '#6E6E78',
        success: '#6FBF8B',
        danger: '#D9705E',
      },
      fontFamily: {
        display: ['Instrument Serif', 'serif'],
        sans: ['Manrope', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      borderRadius: { card: '14px', panel: '16px', field: '10px' },
      spacing: { header: '72px', sidebar: '248px' },
    },
  },
  plugins: [],
};
