import "bootstrap/dist/css/bootstrap.min.css";
import "bootstrap/dist/js/bootstrap.bundle.min.js";
import "@hotwired/turbo-rails";

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

const chatScrollObservers = new Map();

const initChatScrollContainers = () => {
  document.querySelectorAll("[data-chat-scroll-container]").forEach((container) => {
    if (chatScrollObservers.has(container)) return;

    const observer = new MutationObserver((mutations) => {
      const shouldScroll = mutations.some((mutation) =>
        Array.from(mutation.addedNodes).some(
          (node) => node.nodeType === Node.ELEMENT_NODE && node.dataset.chatScrollAnchor === "true"
        )
      );
      if (shouldScroll) {
        container.scrollTop = container.scrollHeight;
      }
    });

    observer.observe(container, { childList: true });
    chatScrollObservers.set(container, observer);
    container.scrollTop = container.scrollHeight;
  });
};

const resetChatScrollObservers = () => {
  chatScrollObservers.forEach((observer) => observer.disconnect());
  chatScrollObservers.clear();
};

const setupChatFormHotkeys = (form) => {
  const textarea = form.querySelector("textarea");
  if (!textarea || textarea.chatFormHotkeyHandler) return;

  const handler = (event) => {
    if (event.key === "Enter" && event.shiftKey && !event.isComposing) {
      event.preventDefault();
      form.requestSubmit();
    }
  };

  textarea.chatFormHotkeyHandler = handler;
  textarea.addEventListener("keydown", handler);
};

const teardownChatFormHotkeys = (form) => {
  const textarea = form.querySelector("textarea");
  if (!textarea || !textarea.chatFormHotkeyHandler) return;

  textarea.removeEventListener("keydown", textarea.chatFormHotkeyHandler);
  delete textarea.chatFormHotkeyHandler;
};

const parseChatExperts = (container) => {
  if (container.cachedExperts) return container.cachedExperts;
  try {
    container.cachedExperts = JSON.parse(container.dataset.chatExperts || "[]");
  } catch (error) {
    console.error("Failed to parse chat experts data", error);
    container.cachedExperts = [];
  }
  return container.cachedExperts;
};

const setupChatContextSelectors = () => {
  document.querySelectorAll("[data-chat-context='true']").forEach((container) => {
    if (container.dataset.chatContextInitialized === "true") return;
    const productSelect = container.querySelector("[data-chat-context-product]");
    const expertSelect = container.querySelector("[data-chat-context-expert]");
    if (!productSelect || !expertSelect) return;

    const experts = parseChatExperts(container);
    const buildOption = (value, label) => {
      const option = document.createElement("option");
      option.value = value;
      option.textContent = label;
      return option;
    };

    const updateExperts = () => {
      const selectedProduct = productSelect.value;
      const previousValue = expertSelect.value;
      const matchingExperts = experts.filter(
        (expert) => String(expert.product_id) === selectedProduct
      );

      expertSelect.innerHTML = "";
      if (!selectedProduct) {
        expertSelect.disabled = true;
        expertSelect.appendChild(buildOption("", "製品を先に選択"));
        expertSelect.value = "";
        return;
      }

      if (matchingExperts.length === 0) {
        expertSelect.disabled = true;
        expertSelect.appendChild(buildOption("", "登録済みの相談相手がありません"));
        expertSelect.value = "";
        return;
      }

      expertSelect.disabled = false;
      expertSelect.appendChild(buildOption("", "未選択"));
      matchingExperts.forEach((expert) => {
        expertSelect.appendChild(buildOption(String(expert.id), expert.name));
      });

      const stillValid = matchingExperts.some((expert) => String(expert.id) === previousValue);
      expertSelect.value = stillValid ? previousValue : "";
    };

    productSelect.addEventListener("change", updateExperts);
    container.dataset.chatContextInitialized = "true";
    container.chatContextCleanup = () => {
      productSelect.removeEventListener("change", updateExperts);
      delete container.dataset.chatContextInitialized;
    };

    updateExperts();
  });
};

const teardownChatContextSelectors = () => {
  document.querySelectorAll("[data-chat-context='true']").forEach((container) => {
    if (container.chatContextCleanup) {
      container.chatContextCleanup();
      delete container.chatContextCleanup;
    }
    delete container.cachedExperts;
  });
};

const initChatForms = () => {
  document.querySelectorAll("form[data-chat-form]").forEach((form) => {
    if (form.dataset.chatFormInitialized === "true") return;
    form.dataset.chatFormInitialized = "true";

    const submitButton = form.querySelector("[data-chat-form-target='submit']");
    setupChatFormHotkeys(form);

    form.addEventListener("turbo:submit-start", () => {
      if (submitButton) submitButton.disabled = true;
    });
    form.addEventListener("turbo:submit-end", (event) => {
      if (submitButton) submitButton.disabled = false;
      if (event.detail && event.detail.successful) {
        const textarea = form.querySelector("textarea");
        if (textarea) textarea.value = "";
      }
    });
  });
};

const initChatUi = () => {
  initChatScrollContainers();
  initChatForms();
  setupChatContextSelectors();
};

document.addEventListener("turbo:load", initChatUi);
document.addEventListener("turbo:frame-load", initChatUi);
document.addEventListener("turbo:render", initChatUi);
document.addEventListener("turbo:before-cache", () => {
  resetChatScrollObservers();
  document.querySelectorAll("form[data-chat-form]").forEach((form) => {
    const submitButton = form.querySelector("[data-chat-form-target='submit']");
    if (submitButton) submitButton.disabled = false;
    teardownChatFormHotkeys(form);
    delete form.dataset.chatFormInitialized;
  });
  teardownChatContextSelectors();
});
