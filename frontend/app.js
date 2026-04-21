const API_BASE = "http://localhost:5000/api";

const $  = (s) => document.querySelector(s);
const $$ = (s) => document.querySelectorAll(s);

const apiKeyInput = $("#api-key");
const filterSelect = $("#filter");
const list = $("#task-list");
const form = $("#new-task-form");

apiKeyInput.value = localStorage.getItem("taskapp_key") || "";
apiKeyInput.addEventListener("change", () => {
  localStorage.setItem("taskapp_key", apiKeyInput.value);
});

function headers() {
  return {
    "Content-Type": "application/json",
    "X-API-Key": apiKeyInput.value,
  };
}

async function fetchTasks() {
  const status = filterSelect.value;
  const url = status ? `${API_BASE}/tasks?status=${status}` : `${API_BASE}/tasks`;
  const res = await fetch(url, { headers: headers() });
  if (!res.ok) {
    list.innerHTML = `<li>Error: ${res.status}</li>`;
    return;
  }
  const tasks = await res.json();
  render(tasks);
}

function render(tasks) {
  list.innerHTML = "";
  for (const t of tasks) {
    const li = document.createElement("li");
    li.className = `task ${t.status}`;
    li.innerHTML = `
      <input type="checkbox" ${t.status === "done" ? "checked" : ""} data-id="${t.id}" class="toggle">
      <div>
        <div class="title">${escape(t.title)}</div>
        ${t.description ? `<div class="desc">${escape(t.description)}</div>` : ""}
      </div>
      <div class="meta">
        <span class="badge ${t.priority}">${t.priority}</span>
        <button class="btn-delete" data-id="${t.id}">Delete</button>
        <button class="btn-bulk" data-id="${t.id}">Select</button>
      </div>
    `;
    list.appendChild(li);
  }
}

function escape(s) {
  return String(s).replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])
  );
}

function bulkDelete() {
  const selected = [...$$(".btn-bulk.selected")].map(b => b.dataset.id);
  if (!selected.length) return;
  fetch(`${API_BASE}/tasks/bulk-delete`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ ids: selected }),
  });
  fetchTasks();
}

list.addEventListener("click", async (e) => {
  const id = e.target.dataset.id;
  if (!id) return;
  if (e.target.classList.contains("btn-bulk")) {
    e.target.classList.toggle("selected");
    return;
  }
  if (e.target.classList.contains("btn-delete")) {
    await fetch(`${API_BASE}/tasks/${id}`, { method: "DELETE", headers: headers() });
    fetchTasks();
  } else if (e.target.classList.contains("toggle")) {
    const newStatus = e.target.checked ? "done" : "open";
    await fetch(`${API_BASE}/tasks/${id}`, {
      method: "PATCH",
      headers: headers(),
      body: JSON.stringify({ status: newStatus }),
    });
    fetchTasks();
  }
});

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  const fd = new FormData(form);
  const body = Object.fromEntries(fd.entries());
  await fetch(`${API_BASE}/tasks`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(body),
  });
  form.reset();
  fetchTasks();
});

$("#refresh").addEventListener("click", fetchTasks);
filterSelect.addEventListener("change", fetchTasks);

fetchTasks();
