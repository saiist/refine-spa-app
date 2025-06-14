import {
  AuthProvider,
  GitHubBanner,
  Refine,
  WelcomePage,
} from "@refinedev/core";
import { DevtoolsPanel, DevtoolsProvider } from "@refinedev/devtools";
import { RefineKbar, RefineKbarProvider } from "@refinedev/kbar";

import { useNotificationProvider } from "@refinedev/antd";
import "@refinedev/antd/dist/reset.css";

import { useKeycloak } from "@react-keycloak/web";
import routerBindings, {
  DocumentTitleHandler,
  UnsavedChangesNotifier,
} from "@refinedev/react-router";
import dataProvider from "@refinedev/simple-rest";
import { App as AntdApp } from "antd";
import axios from "axios";
import { BrowserRouter, Route, Routes } from "react-router";
import { ColorModeContextProvider } from "./contexts/color-mode";

function App() {
  const { keycloak, initialized } = useKeycloak();

  if (!initialized) {
    return <div>Loading...</div>;
  }

  const authProvider: AuthProvider = {
    login: async () => {
      const urlSearchParams = new URLSearchParams(window.location.search);
      const { to } = Object.fromEntries(urlSearchParams.entries());
      await keycloak.login({
        redirectUri: to ? `${window.location.origin}${to}` : undefined,
      });
      return {
        success: true,
      };
    },
    logout: async () => {
      try {
        await keycloak.logout({
          redirectUri: window.location.origin,
        });
        return {
          success: true,
          redirectTo: "/login",
        };
      } catch (error) {
        return {
          success: false,
          error: new Error("Logout failed"),
        };
      }
    },
    onError: async (error) => {
      console.error(error);
      return { error };
    },
    check: async () => {
      try {
        const { token } = keycloak;
        if (token) {
          axios.defaults.headers.common = {
            Authorization: `Bearer ${token}`,
          };
          return {
            authenticated: true,
          };
        } else {
          return {
            authenticated: false,
            logout: true,
            redirectTo: "/login",
            error: {
              message: "Check failed",
              name: "Token not found",
            },
          };
        }
      } catch (error) {
        return {
          authenticated: false,
          logout: true,
          redirectTo: "/login",
          error: {
            message: "Check failed",
            name: "Token not found",
          },
        };
      }
    },
    getPermissions: async () => null,
    getIdentity: async () => {
      if (keycloak?.tokenParsed) {
        return {
          name: keycloak.tokenParsed.family_name,
        };
      }
      return null;
    },
  };

  return (
    <BrowserRouter>
      <GitHubBanner />
      <RefineKbarProvider>
        <ColorModeContextProvider>
          <AntdApp>
            <DevtoolsProvider>
              <Refine
                dataProvider={dataProvider("https://api.fake-rest.refine.dev")}
                notificationProvider={useNotificationProvider}
                routerProvider={routerBindings}
                authProvider={authProvider}
                options={{
                  syncWithLocation: true,
                  warnWhenUnsavedChanges: true,
                  useNewQueryKeys: true,
                  projectId: "4yKmLC-bVur67-5uljj9",
                }}
              >
                <Routes>
                  <Route index element={<WelcomePage />} />
                </Routes>
                <RefineKbar />
                <UnsavedChangesNotifier />
                <DocumentTitleHandler />
              </Refine>
              <DevtoolsPanel />
            </DevtoolsProvider>
          </AntdApp>
        </ColorModeContextProvider>
      </RefineKbarProvider>
    </BrowserRouter>
  );
}

export default App;
