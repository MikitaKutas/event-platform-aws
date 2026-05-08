"use strict";

const API_BASE_URL =
  (window.__CONFIG__ && window.__CONFIG__.API_BASE_URL) || "";

const form = document.getElementById("event-form");
const formStatus = document.getElementById("form-status");
const refreshBtn = document.getElementById("refresh-stats");
const statsUpdated = document.getElementById("stats-updated");
const chartCanvas = document.getElementById("stats-chart");

let statsChart;

function setStatus(msg, kind) {
  formStatus.textContent = msg;
  formStatus.className = "status" + (kind ? " " + kind : "");
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

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  const fd = new FormData(form);
  const payload = {
    name: (fd.get("name") || "").toString().trim(),
    date: (fd.get("date") || "").toString(),
    description: (fd.get("description") || "").toString().trim(),
  };
  if (!payload.name || !payload.date) {
    setStatus("Название и дата обязательны", "err");
    return;
  }
  setStatus("Отправка…");
  try {
    const data = await apiFetch("/event", {
      method: "POST",
      body: JSON.stringify(payload),
    });
    setStatus(`Мероприятие создано (id: ${data.id || "?"})`, "ok");
    form.reset();
    await loadStats();
  } catch (err) {
    setStatus("Ошибка: " + err.message, "err");
  }
});

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
    renderChart(arr);
    statsUpdated.textContent = "Обновлено " + new Date().toLocaleTimeString();
  } catch (err) {
    statsUpdated.textContent = "Ошибка: " + err.message;
  } finally {
    refreshBtn.disabled = false;
  }
}

refreshBtn.addEventListener("click", loadStats);

loadStats();
