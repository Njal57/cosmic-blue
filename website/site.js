// Graphics card choice: NVIDIA swaps the ISO links and the image name.
// Remembered per browser; ?gpu=nvidia in the address selects it too.
const setGpu = (gpu) => {
  const nvidia = gpu === "nvidia";
  for (const link of document.querySelectorAll("[data-nvidia-href]")) {
    link.dataset.mainHref ??= link.getAttribute("href");
    link.setAttribute("href", nvidia ? link.dataset.nvidiaHref : link.dataset.mainHref);
  }
  for (const el of document.querySelectorAll("[data-nvidia-only]")) el.hidden = !nvidia;
  for (const el of document.querySelectorAll("[data-image]")) {
    el.textContent = nvidia ? "cosmic-blue-nvidia" : "cosmic-blue";
  }
  document.querySelector(`input[name="gpu"][value="${nvidia ? "nvidia" : "main"}"]`).checked = true;
};
let gpu = new URLSearchParams(location.search).get("gpu");
try { gpu ??= localStorage.getItem("gpu"); } catch {}
setGpu(gpu);
for (const input of document.querySelectorAll('input[name="gpu"]')) {
  input.addEventListener("change", () => {
    setGpu(input.value);
    try { localStorage.setItem("gpu", input.value); } catch {}
  });
}

// Copy buttons: labels follow the page language.
const labels = {
  en: { copy: "Copy", copied: "Copied", failed: "Select and copy" },
  fr: { copy: "Copier", copied: "Copié", failed: "Sélectionnez et copiez" },
}[document.documentElement.lang] ?? { copy: "Copy", copied: "Copied", failed: "Select and copy" };

for (const button of document.querySelectorAll("[data-copy]")) {
  button.addEventListener("click", async () => {
    const text = button.previousElementSibling.innerText;
    try {
      await navigator.clipboard.writeText(text);
      button.textContent = labels.copied;
    } catch {
      button.textContent = labels.failed;
    }
    setTimeout(() => { button.textContent = labels.copy; }, 2000);
  });
}
