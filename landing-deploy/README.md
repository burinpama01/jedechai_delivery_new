# JDC Delivery Landing Deploy

Standalone public landing-page package.

Deploy this folder as a separate static site:

- `index.html` - public landing page
- `reset-password.html` - password reset page used by app links
- `assets/images/*` - landing visual assets
- `config.production.js` - public Supabase anon config only
- `_headers`, `_redirects` - Netlify/Cloudflare Pages style config
- `vercel.json` - Vercel routing and headers

Do not add Supabase service-role keys to this folder.

