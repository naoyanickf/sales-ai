import "bootstrap/dist/css/bootstrap.min.css";
import "bootstrap/dist/js/bootstrap.bundle.min.js";

import * as ActiveStorage from "@rails/activestorage";
import React from "react";
import { createRoot } from "react-dom/client";
import HelloWorld from "./HelloWorld.jsx";

ActiveStorage.start();

const DIRECT_UPLOAD_STATUS_SELECTOR = ".direct-upload-status";

const findStatusContainer = (input) => {
  if (!input) return null;

  const form = input.closest("form");
  if (!form) return null;

  let container = form.querySelector(DIRECT_UPLOAD_STATUS_SELECTOR);
  if (!container) {
    container = document.createElement("div");
    container.className = "direct-upload-status list-group small mb-3";
    input.insertAdjacentElement("afterend", container);
  }

  container.classList.remove("d-none");
  return container;
};

const updateUploadStatusText = (item, text, className = "") => {
  if (!item) return;
  const statusText = item.querySelector(".upload-status-text");
  if (statusText) {
    statusText.textContent = text;
    statusText.className = `upload-status-text ${className}`.trim();
  }
};

document.addEventListener("direct-upload:initialize", (event) => {
  const { target, detail } = event;
  const { id, file } = detail;

  const container = findStatusContainer(target);
  if (!container) return;

  const item = document.createElement("div");
  item.id = `direct-upload-${id}`;
  item.className = "list-group-item";

  const header = document.createElement("div");
  header.className = "d-flex justify-content-between align-items-center";

  const filenameSpan = document.createElement("span");
  filenameSpan.className = "text-truncate pe-3";
  filenameSpan.textContent = file.name;
  filenameSpan.title = file.name;

  const statusSpan = document.createElement("span");
  statusSpan.className = "upload-status-text text-muted small";
  statusSpan.textContent = "準備中";

  header.appendChild(filenameSpan);
  header.appendChild(statusSpan);

  const progressWrapper = document.createElement("div");
  progressWrapper.className = "progress mt-2";
  progressWrapper.setAttribute("role", "progressbar");
  progressWrapper.setAttribute("aria-valuemin", "0");
  progressWrapper.setAttribute("aria-valuemax", "100");

  const progressBar = document.createElement("div");
  progressBar.className = "progress-bar progress-bar-striped progress-bar-animated";
  progressBar.style.width = "0%";

  progressWrapper.appendChild(progressBar);

  item.appendChild(header);
  item.appendChild(progressWrapper);

  container.appendChild(item);
});

document.addEventListener("direct-upload:progress", (event) => {
  const { id, progress } = event.detail;
  const item = document.getElementById(`direct-upload-${id}`);
  if (!item) return;

  const numericProgress = Number(progress) || 0;
  const clampedProgress = Math.min(Math.max(numericProgress, 0), 100);
  const displayProgress = (Math.round(clampedProgress * 10) / 10).toFixed(1);

  const bar = item.querySelector(".progress-bar");
  if (bar) {
    bar.style.width = `${clampedProgress}%`;
    bar.setAttribute("aria-valuenow", clampedProgress);
  }

  updateUploadStatusText(item, `アップロード中 ${displayProgress}%`);
});

document.addEventListener("direct-upload:error", (event) => {
  const { id, error } = event.detail;
  const item = document.getElementById(`direct-upload-${id}`);
  if (!item) return;

  updateUploadStatusText(item, `失敗: ${error}`, "text-danger");

  const bar = item.querySelector(".progress-bar");
  if (bar) {
    bar.classList.remove("progress-bar-animated");
    bar.classList.add("bg-danger");
  }
});

document.addEventListener("direct-upload:end", (event) => {
  const { id } = event.detail;
  const item = document.getElementById(`direct-upload-${id}`);
  if (!item) return;

  const bar = item.querySelector(".progress-bar");
  if (bar) {
    bar.classList.remove("progress-bar-animated");
    bar.classList.add("bg-success");
    bar.style.width = "100%";
  }

  updateUploadStatusText(item, "アップロード完了", "text-success");

  setTimeout(() => {
    item.classList.add("opacity-50");
  }, 500);

  setTimeout(() => {
    const container = item.parentElement;
    item.remove();
    if (container && container.children.length === 0) {
      container.classList.add("d-none");
    }
  }, 4000);
});

document.addEventListener("DOMContentLoaded", () => {
  const mountPoint = document.getElementById("dev-react-root");

  if (!mountPoint) return;

  const root = createRoot(mountPoint);
  root.render(<HelloWorld />);
});
