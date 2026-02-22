import { themes as prismThemes } from "prism-react-renderer";
import type { Config } from "@docusaurus/types";
import type * as Preset from "@docusaurus/preset-classic";

const config: Config = {
  title: "ZigTUI",
  tagline: "A fast, allocation-free TUI library for Zig",
  favicon: "img/favicon.ico",

  url: "https://adxdits.github.io",
  baseUrl: "/zigtui/",

  organizationName: "adxdits",
  projectName: "zigtui",
  trailingSlash: false,

  onBrokenLinks: "throw",
  onBrokenMarkdownLinks: "warn",

  i18n: {
    defaultLocale: "en",
    locales: ["en"],
  },

  presets: [
    [
      "classic",
      {
        docs: {
          sidebarPath: "./sidebars.ts",
        },
        blog: false,
        theme: {
          customCss: "./src/css/custom.css",
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: "img/social-card.png",
    colorMode: {
      defaultMode: "dark",
      disableSwitch: false,
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: "ZigTUI",
      logo: {
        alt: "ZigTUI Logo",
        src: "img/logo.svg",
      },
      items: [
        {
          type: "docSidebar",
          sidebarId: "docsSidebar",
          position: "left",
          label: "Docs",
        },
        {
          href: "https://github.com/adxdits/zigtui",
          label: "GitHub",
          position: "right",
        },
      ],
    },
    footer: {
      style: "dark",
      links: [
        {
          title: "Docs",
          items: [
            { label: "Getting Started", to: "/docs/getting-started" },
            { label: "Widgets", to: "/docs/widgets/block" },
            { label: "Themes", to: "/docs/themes" },
          ],
        },
        {
          title: "More",
          items: [
            { label: "GitHub", href: "https://github.com/adxdits/zigtui" },
            {
              label: "Report an Issue",
              href: "https://github.com/adxdits/zigtui/issues",
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} ZigTUI. MIT License.`,
    },
    prism: {
      theme: prismThemes.oneDark,
      darkTheme: prismThemes.oneDark,
      additionalLanguages: ["zig", "bash"],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
