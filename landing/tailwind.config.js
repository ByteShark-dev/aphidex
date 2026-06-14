/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './privacy/**/*.html', './src/**/*.js'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        background: '#071518',
        surface: '#071518',
        'surface-container-lowest': '#040d10',
        'surface-container-low': '#091a1f',
        'surface-container': '#0d2328',
        'surface-container-high': '#143239',
        'surface-container-highest': '#1c454f',
        primary: '#f6fffa',
        'on-primary': '#082117',
        'primary-container': '#7ce0a7',
        'on-primary-container': '#052012',
        secondary: '#9fb8b3',
        'secondary-container': '#12332d',
        'on-secondary-container': '#f6fffa',
        outline: '#8aa39f',
        'outline-variant': '#31534d',
        'on-surface': '#f3fcfa',
        'on-surface-variant': '#a6c0bb',
        'surface-tint': '#7ce0a7',
        accent: '#f0c15d',
        error: '#ff6b6b'
      },
      borderRadius: {
        DEFAULT: '0.125rem',
        lg: '0.25rem',
        xl: '0.5rem',
        full: '0.75rem',
      },
      fontFamily: {
        headline: ['Space Grotesk', 'Montserrat', 'sans-serif'],
        body: ['Montserrat', 'sans-serif'],
        label: ['Space Grotesk', 'Montserrat', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
