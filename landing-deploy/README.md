# JDC Delivery Landing Deploy

Standalone public landing-page package.

Deploy this folder as a separate static site on Vercel (Root Directory = `landing-deploy`, Framework Preset = `Other`, no build command):

- `index.html` - public landing page
- `reset-password.html` - password reset page used by app links
- `assets/images/*` - landing visual assets
- `config.production.js` - public Supabase anon config only
- `vercel.json` - Vercel routing (rewrites) and security headers

Do not add Supabase service-role keys to this folder.

