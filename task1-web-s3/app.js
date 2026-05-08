"use strict";

const API_BASE_URL =
  (window.__CONFIG__ && window.__CONFIG__.API_BASE_URL) || "";

const eventForm = document.getElementById("event-form");
const eventFormStatus = document.getElementById("form-status");

const registerForm = document.getElementById("register-form");
const registerFormStatus = document.getElementById("register-status");
const registerEventSelect = document.getElementById("register-event-select");

const refreshBtn = document.getElementById("refresh-stats");
const statsUpdated = document.getElementById("stats-updated");
const chartCanvas = document.getElementById("stats-chart");

let statsChart;
let lastStats = [];

function setStatus(el, msg, kind) {
  el.textContent = msg;
  el.className = "status" + (kind ? " " + kind : "");
}

async function apiFetch(path, options = {}) {
  if (!API_BASE_URL) {
    throw new Error("API_BASE_URL не настроен (см. config.js)");
  }
  const resp = await fetch(API_BASE_URL.replace(/\/$/, "") + path, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!resp.ok) {
    const body = await resp.text().catch(() => "");
    throw new Error(`HTTP ${resp.status}${body ? ": " + body : ""}`);
  }
  return resp.json();
}

// ---------- create event ----------
eventForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const fd = new FormData(eventForm);
  const payload = {
    name: (fd.get("name") || "").toString().trim(),
    date: (fd.get("date") || "").toString(),
    description: (fd.get("description") || "").toString().trim(),
  };
  if (!payload.name || !payload.date) {
    setStatus(eventFormStatus, "Название и дата обязательны", "err");
    return;
  }
  setStatus(eventFormStatus, "Отправка…");
  try {
    const data = await apiFetch("/event", {
      method: "POST",
      body: JSON.stringify(payload),
    });
    setStatus(
      eventFormStatus,
      `Мероприятие создано (id: ${data.id || "?"})`,
      "ok",
    );
    eventForm.reset();
    await loadStats();
  } catch (err) {
    setStatus(eventFormStatus, "Ошибка: " + err.message, "err");
  }
});

registerForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const fd = new FormData(registerForm);
  const payload = {
    eventId: (fd.get("eventId") || "").toString(),
    userName: (fd.get("userName") || "").toString().trim(),
    email: (fd.get("email") || "").toString().trim(),
  };
  if (!payload.eventId) {
    setStatus(registerFormStatus, "Выбери мероприятие", "err");
    return;
  }
  if (!payload.userName || !payload.email) {
    setStatus(registerFormStatus, "Имя и email обязательны", "err");
    return;
  }
  setStatus(registerFormStatus, "Отправка…");
  try {
    const data = await apiFetch("/register", {
      method: "POST",
      body: JSON.stringify(payload),
    });
    const eventName =
      (lastStats.find((s) => s.event_id === payload.eventId) || {}).name ||
      "мероприятие";
    setStatus(
      registerFormStatus,
      `Регистрация принята: ${data.userName} → ${eventName}`,
      "ok",
    );

    registerForm.querySelector('input[name="userName"]').value = "";
    registerForm.querySelector('input[name="email"]').value = "";
    await loadStats();
  } catch (err) {
    setStatus(registerFormStatus, "Ошибка: " + err.message, "err");
  }
});

function populateEventSelect(stats) {
  const prevValue = registerEventSelect.value;
  if (!stats.length) {
    registerEventSelect.innerHTML =
      '<option value="">Сначала создай мероприятие</option>';
    return;
  }
  registerEventSelect.innerHTML =
    '<option value="">— выбери мероприятие —</option>' +
    stats
      .map(
        (s) =>
          `<option value="${s.event_id}">${escapeHtml(s.name || s.event_id)} — ${s.date || ""}</option>`,
      )
      .join("");

  if (prevValue && stats.some((s) => s.event_id === prevValue)) {
    registerEventSelect.value = prevValue;
  }
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function renderChart(stats) {
  const labels = stats.map((s) => s.name || s.event_id);
  const values = stats.map((s) => s.registrations ?? s.count ?? 0);
  const data = {
    labels,
    datasets: [
      {
        label: "Регистрации",
        data: values,
        backgroundColor: "rgba(37, 99, 235, 0.55)",
        borderColor: "rgba(37, 99, 235, 1)",
        borderWidth: 1,
      },
    ],
  };
  if (statsChart) {
    statsChart.data = data;
    statsChart.update();
  } else {
    statsChart = new Chart(chartCanvas, {
      type: "bar",
      data,
      options: {
        responsive: true,
        scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
        plugins: { legend: { display: false } },
      },
    });
  }
}

async function loadStats() {
  refreshBtn.disabled = true;
  statsUpdated.textContent = "Загрузка…";
  try {
    const data = await apiFetch("/stats");
    const arr = Array.isArray(data) ? data : data.items || [];
    lastStats = arr;
    renderChart(arr);
    populateEventSelect(arr);
    statsUpdated.textContent = "Обновлено " + new Date().toLocaleTimeString();
  } catch (err) {
    statsUpdated.textContent = "Ошибка: " + err.message;
    registerEventSelect.innerHTML =
      '<option value="">Не удалось загрузить список</option>';
  } finally {
    refreshBtn.disabled = false;
  }
}

refreshBtn.addEventListener("click", loadStats);

loadStats();
