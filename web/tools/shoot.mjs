// Nimmt die Seite ganzseitig und abschnittsweise auf — zum Prüfen des
// Entwurfs und für die Vorschau im README.
import puppeteer from 'puppeteer-core'

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
const url = process.argv[2] ?? 'http://localhost:5178/'
const out = process.argv[3] ?? '/tmp'

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: 'new',
  args: ['--hide-scrollbars', '--force-device-scale-factor=2'],
  defaultViewport: { width: 1440, height: 950, deviceScaleFactor: 2 },
})
const page = await browser.newPage()
await page.goto(url, { waitUntil: 'networkidle0' })
// Einmal ganz durchscrollen, damit alles Eingeblendete sichtbar ist.
await page.evaluate(async () => {
  document.documentElement.style.scrollBehavior = 'auto'
  const height = document.body.scrollHeight
  for (let y = 0; y < height; y += 500) {
    window.scrollTo(0, y)
    await new Promise((r) => setTimeout(r, 90))
  }
  window.scrollTo(0, 0)
})
await new Promise((r) => setTimeout(r, 1200))

for (const id of ['top', 'demo', 'funktionen', 'fenster', 'terminal', 'grenzen', 'loslegen']) {
  await page.evaluate((anchor) => {
    const node = document.getElementById(anchor)
    if (node) window.scrollTo(0, node.getBoundingClientRect().top + window.scrollY - 10)
  }, id)
  await new Promise((r) => setTimeout(r, 900))
  await page.screenshot({ path: `${out}/site-${id}.png` })
  console.log(`✓ site-${id}.png`)
}

await page.screenshot({ path: `${out}/site-full.png`, fullPage: true })
console.log('✓ site-full.png')
await browser.close()
