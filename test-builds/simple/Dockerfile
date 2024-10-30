FROM node:18-alpine

WORKDIR /app

RUN echo '{"name":"test","version":"1.0.0","dependencies":{"express":"^4.18.2"}}' > package.json

RUN npm install

RUN mkdir src
COPY . .

RUN npm install -g typescript && \
    echo '{"compilerOptions":{"target":"es6","outDir":"dist"}}' > tsconfig.json && \
    mkdir -p src && \
    echo 'const greeting: string = "Hello World"; console.log(greeting);' > src/main.ts && \
    tsc

CMD ["node", "dist/main.js"]