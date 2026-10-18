set -euo pipefail
cp -R "$(dirname "$0")/../../fixture/." .
cat > src/pages/index.astro <<'EOF'
---
import Layout from '../layouts/Layout.astro';
---

<Layout title="Studio">
  <section class="hero"><h1><a href="/">STUDIO</a></h1><p class="scroll-cue">Scroll</p></section>
  <section class="work"><h2><a href="/work">Selected work</a></h2></section>
  <section class="contact"><h2>Contact</h2></section>
</Layout>
EOF
cat > src/pages/work.astro <<'EOF'
---
import Layout from '../layouts/Layout.astro';
---

<Layout title="Work | Studio">
  <section class="work-index"><h1>Work</h1><a href="/">Home</a></section>
</Layout>
EOF
