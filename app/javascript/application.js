import React from "react";
import { createRoot } from "react-dom/client";
import HelloWorld from "./HelloWorld.jsx";

document.addEventListener("DOMContentLoaded", () => {
  const mountPoint = document.getElementById("dev-react-root");

  if (!mountPoint) return;

  const root = createRoot(mountPoint);
  root.render(<HelloWorld />);
});
