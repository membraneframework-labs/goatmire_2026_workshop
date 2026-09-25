import { defineMermaidSetup } from '@slidev/types'

export default defineMermaidSetup(() => ({
  theme: 'base',
  look: 'classic',
  flowchart: {
    padding: 8,
    nodeSpacing: 30,
    rankSpacing: 40,
  },
  themeVariables: {
    fontFamily: 'DM Sans, sans-serif',
    primaryColor: '#87CCE8',
    primaryTextColor: '#001A72',
    primaryBorderColor: '#001A72',
    lineColor: '#001A72',
    secondaryColor: '#FFFFFF',
    tertiaryColor: '#E9F6FB',
    dropShadow: 'none',
  },
}))
