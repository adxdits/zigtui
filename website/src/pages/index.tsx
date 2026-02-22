import type { ReactNode } from "react";
import Link from "@docusaurus/Link";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";
import Layout from "@theme/Layout";
import Heading from "@theme/Heading";
import clsx from "clsx";
import styles from "./index.module.css";

type Feature = {
  icon: string;
  title: string;
  description: string;
};

const features: Feature[] = [
  {
    icon: "",
    title: "Cell-Based Diffing",
    description:
      "Only redraws cells that actually changed your terminal stays flicker-free even on fast refresh loops.",
  },
  {
    icon: "",
    title: "14+ Widgets",
    description:
      "Block, Paragraph, List, Gauge, Table, Tabs, Sparkline, BarChart, TextInput, Spinner, Tree, Canvas, Popup, Dialog all ready to use.",
  },
  {
    icon: "",
    title: "Mouse Support",
    description:
      "Full SGR mouse events on Unix and the native Console API on Windows. Click, scroll, and drag just work.",
  },
  {
    icon: "",
    title: "15 Built-in Themes",
    description:
      "Nord, Dracula, Gruvbox, Catppuccin, Tokyo Night and more. Hot-swap themes at runtime with a single line.",
  },
  {
    icon: "",
    title: "Kitty Graphics",
    description:
      "Display BMP images in Kitty, WezTerm and foot via the Kitty Graphics Protocol. Unicode-block fallback for other terminals.",
  },
  {
    icon: "",
    title: "No Hidden Allocations",
    description:
      "All allocations go through the allocator you supply. Stack buffers, comptime sizing you stay in control of memory.",
  },
];

function FeatureCard({ icon, title, description }: Feature): ReactNode {
  return (
    <div className={clsx("col col--4", styles.featureCardWrapper)}>
      <div className="feature-card">
        <div className={styles.featureIcon}>{icon}</div>
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

function HomepageHero(): ReactNode {
  const { siteConfig } = useDocusaurusContext();
  return (
    <header className={clsx("hero hero--primary", styles.heroBanner)}>
      <div className="container">
        <Heading as="h1" className="hero__title">
          {siteConfig.title}
        </Heading>
        <p className="hero__subtitle">{siteConfig.tagline}</p>

        <div className={styles.installBlock}>
          <code className={styles.installCmd}>
            zig fetch --save git+https://github.com/adxdits/zigtui.git
          </code>
        </div>

        <div className={styles.buttons}>
          <Link
            className="button button--primary button--lg"
            to="/docs/getting-started"
          >
            Get Started
          </Link>
          <Link
            className="button button--secondary button--lg"
            href="https://github.com/adxdits/zigtui"
          >
            GitHub ↗
          </Link>
        </div>

        <div className="hero-badges" style={{ marginTop: "1.5rem" }}>
          <img
            alt="Zig 0.15+"
            src="https://img.shields.io/badge/zig-0.15%2B-f7a41d?logo=zig&logoColor=white"
          />
          <img
            alt="License MIT"
            src="https://img.shields.io/badge/license-MIT-blue"
          />
          <img
            alt="Platforms"
            src="https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey"
          />
        </div>
      </div>
    </header>
  );
}

export default function Home(): ReactNode {
  return (
    <Layout title="ZigTUI TUI library for Zig" description="A fast, allocation-free TUI library for Zig. Inspired by Ratatui. Works on Windows, Linux, and macOS.">
      <HomepageHero />
      <main>
        <section className={styles.features}>
          <div className="container">
            <div className="row">
              {features.map((f) => (
                <FeatureCard key={f.title} {...f} />
              ))}
            </div>
          </div>
        </section>

        {/* Quick demo code */}
        <section className={styles.demoSection}>
          <div className="container">
            <Heading as="h2">Minimal example</Heading>
            <pre className={styles.demoCode}>
              <code>{`const std = @import("std");
const tui = @import("zigtui");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var backend = try tui.backend.init(gpa.allocator());
    defer backend.deinit();

    var terminal = try tui.terminal.Terminal.init(gpa.allocator(), backend.interface());
    defer terminal.deinit();

    try terminal.hideCursor();
    defer terminal.showCursor() catch {};

    var running = true;
    while (running) {
        const event = try backend.interface().pollEvent(100);
        if (event == .key) {
            const k = event.key.code;
            if (k == .esc or (k == .char and k.char == 'q'))
                running = false;
        }

        try terminal.draw({}, struct {
            fn render(_: void, buf: *tui.render.Buffer) !void {
                tui.widgets.Block{
                    .title = "Hello ZigTUI press 'q' to quit",
                    .borders = tui.widgets.Borders.all(),
                    .border_style = .{ .fg = .cyan },
                }.render(buf.getArea(), buf);
            }
        }.render);
    }
}`}</code>
            </pre>
          </div>
        </section>
      </main>
    </Layout>
  );
}
