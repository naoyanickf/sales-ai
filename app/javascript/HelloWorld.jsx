import React from "react";

const HelloWorld = ({ message = "Hello from React!" }) => (
  <div className="card shadow-sm">
    <div className="card-body">
      <h2 className="card-title fs-4">{message}</h2>
      <p className="card-text text-body-secondary">
        Bootstrap 5.3 is now available in this project.
      </p>
      <button type="button" className="btn btn-primary">
        Let&apos;s build
      </button>
    </div>
  </div>
);

export default HelloWorld;
