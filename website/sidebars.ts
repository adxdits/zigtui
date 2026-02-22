import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebars: SidebarsConfig = {
  docsSidebar: [
    {
      type: "doc",
      id: "getting-started",
      label: "Getting Started",
    },
    {
      type: "category",
      label: "Widgets",
      collapsed: false,
      items: [
        "widgets/block",
        "widgets/paragraph",
        "widgets/list",
        "widgets/gauge",
        "widgets/table",
        "widgets/tabs",
        "widgets/sparkline",
        "widgets/bar-chart",
        "widgets/text-input",
        "widgets/spinner",
        "widgets/tree",
        "widgets/canvas",
        "widgets/popup",
        "widgets/dialog",
      ],
    },
    {
      type: "doc",
      id: "themes",
      label: "Themes",
    },
    {
      type: "doc",
      id: "kitty-graphics",
      label: "Kitty Graphics",
    },
    {
      type: "doc",
      id: "platform-support",
      label: "Platform Support",
    },
  ],
};

export default sidebars;
