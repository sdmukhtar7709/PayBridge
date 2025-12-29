const serviceToggle = document.getElementById("serviceToggle");
const serviceStatus = document.getElementById("serviceStatus");

serviceToggle.addEventListener("change", () => {
  if (serviceToggle.checked) {
    serviceStatus.textContent = "Service Active";
    alert("Service enabled (demo)");
  } else {
    serviceStatus.textContent = "Service Stopped";
    alert("Service stopped temporarily (demo)");
  }

  // TODO: Backend API will enable/disable platform services
});

function approveAgent() {
  alert("Agent approved (demo)");
  console.log("Approve agent");

  // TODO: Backend API to approve agent
}

function rejectAgent() {
  alert("Agent rejected (demo)");
  console.log("Reject agent");

  // TODO: Backend API to reject agent
}

function viewDocs() {
  alert("Viewing agent documents (demo)");
  console.log("View documents");

  // TODO: Backend will fetch and display agent documents
}

function viewProfile() {
  alert("Opening agent profile (demo)");
  console.log("View agent profile");

  // TODO: Backend will fetch and display agent profile details
}
