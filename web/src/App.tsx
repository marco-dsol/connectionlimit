import { Nav } from './components/Nav'
import { Hero } from './components/Hero'
import { LiveDemo } from './components/LiveDemo'
import { Features } from './components/Features'
import { Shots } from './components/Shots'
import { TerminalDemo } from './components/TerminalDemo'
import { Honest } from './components/Honest'
import { Start } from './components/Start'
import { Footer } from './components/Footer'
import { Legal } from './components/Legal'

export default function App() {
  return (
    <>
      <div className="backdrop" />
      <Nav />
      <Hero />
      <LiveDemo />
      <Features />
      <Shots />
      <TerminalDemo />
      <Honest />
      <Start />
      <Footer />
      <Legal />
    </>
  )
}
