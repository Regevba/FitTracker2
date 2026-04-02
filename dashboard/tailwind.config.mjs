/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        brand: {
          primary: '#FA8F40',
          secondary: '#8AC7FF',
          warm: '#FFC78A',
          cool: '#DFF3FF',
        },
        surface: {
          primary: { DEFAULT: '#FFFFFF', dark: '#0F1419' },
          secondary: { DEFAULT: '#F8F9FA', dark: '#1A1F2E' },
          tertiary: { DEFAULT: '#F1F3F5', dark: '#242938' },
        },
        status: {
          backlog: '#9CA3AF',
          research: '#9CA3AF',
          prd: '#9CA3AF',
          ux: '#3B82F6',
          integration: '#3B82F6',
          implement: '#3B82F6',
          testing: '#A855F7',
          review: '#A855F7',
          merge: '#A855F7',
          docs: '#10B981',
          done: '#10B981',
        },
        priority: {
          critical: '#DC2626',
          high: '#F59E0B',
          medium: '#FBBF24',
          low: '#D1D5DB',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        mono: ['SF Mono', 'Menlo', 'monospace'],
      },
      borderRadius: {
        card: '12px',
        badge: '6px',
      },
      boxShadow: {
        card: '0 4px 10px rgba(0, 0, 0, 0.08)',
        'card-hover': '0 8px 20px rgba(0, 0, 0, 0.12)',
        'card-drag': '0 12px 28px rgba(0, 0, 0, 0.18)',
      },
    },
  },
  plugins: [],
};
