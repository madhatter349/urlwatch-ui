import type { RequestHandler } from "@sveltejs/kit";
import { access, mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

export interface Config {
  urlwatchPath: string;
}

export interface ConfigResponse {
  config: Config | null;
  error?: string;
}

const CONFIG_FILEPATH =
  process.env.CONFIG_FILEPATH ?? `${process.cwd()}/data/config.json`;

const DEFAULT_CONFIG = {
  urlwatchPath: null,
};

const getConfig = async (): Promise<Config> => {
  await access(CONFIG_FILEPATH);
  const configFile = await readFile(CONFIG_FILEPATH, "utf8");
  return JSON.parse(configFile) as Config;
};

const createConfig = async () => {
  const directory = resolve(CONFIG_FILEPATH, "..");
  await mkdir(directory, { recursive: true });
  await writeFile(
    CONFIG_FILEPATH,
    JSON.stringify(DEFAULT_CONFIG, null, 2),
    "utf8"
  );
};

const updateConfig = async (config: Partial<Config>): Promise<Config> => {
  const currentConfig = await getConfig();
  const newConfig = { ...currentConfig, ...config };
  await writeFile(CONFIG_FILEPATH, JSON.stringify(newConfig, null, 2), "utf8");
  return newConfig;
};

export const GET: RequestHandler<
  Record<string, string>,
  ConfigResponse
> = async (...args) => {
  try {
    const config = await getConfig();
    return {
      status: 200,
      body: { config },
    };
  } catch (err: any) {
    if (err.code === "ENOENT") {
      try {
        await createConfig();
        return GET(...args);
      } catch (err) {
        return {
          status: 500,
          body: {
            config: null,
            error: `Could not create app config file at ${CONFIG_FILEPATH}. Please create it manually: ${err}`,
          },
        };
      }
    }
    return {
      status: 500,
      body: {
        config: null,
        error: `Error accessing config: ${err}`,
      },
    };
  }
};

export const PATCH: RequestHandler<
  Record<string, string>,
  ConfigResponse
> = async ({ request }) => {
  const patch = (await request.json()) as Partial<Config>;
  try {
    const config = await updateConfig(patch);
    return {
      status: 200,
      body: { config },
    };
  } catch (err: any) {
    return {
      status: 500,
      body: {
        config: null,
        error: `Error updating config: ${err}`,
      },
    };
  }
};
