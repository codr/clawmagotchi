/** @jsxImportSource @emotion/react */
import { css } from '@emotion/react';

const main = css`
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
`;

export default function Home() {
  return (
    <main css={main}>
      <h1>Clawmagotchi</h1>
    </main>
  );
}
