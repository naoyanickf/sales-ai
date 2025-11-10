import React from "react";

const HelloWorld = ({ message = "Hello from React!" }) => (
  <section className="dev-react-hello">
    <h2>{message}</h2>
    <p>This component lives in app/javascript.</p>
  </section>
);

export default HelloWorld;
