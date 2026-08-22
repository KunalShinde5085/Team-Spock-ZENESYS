import { Route, Routes } from "react-router-dom";
import { AppLayout } from "@/components/layout/AppLayout";
import Dashboard from "@/pages/Dashboard";
import Orders from "@/pages/Orders";
import OrderDetails from "@/pages/OrderDetails";
import OrderForm from "@/pages/OrderForm";
import Inventory from "@/pages/Inventory";
import InventoryDetails from "@/pages/InventoryDetails";
import Production from "@/pages/Production";
import Forecast from "@/pages/Forecast";
import Recommendations from "@/pages/Recommendations";
import Alerts from "@/pages/Alerts";
import Analytics from "@/pages/Analytics";
import Settings from "@/pages/Settings";
import NotFound from "@/pages/NotFound";

export default function App() {
  return (
    <Routes>
      <Route element={<AppLayout />}>
        <Route path="/" element={<Dashboard />} />
        <Route path="/orders" element={<Orders />} />
        <Route path="/orders/new" element={<OrderForm />} />
        <Route path="/orders/:id" element={<OrderDetails />} />
        <Route path="/orders/:id/edit" element={<OrderForm />} />
        <Route path="/inventory" element={<Inventory />} />
        <Route path="/inventory/:id" element={<InventoryDetails />} />
        <Route path="/production" element={<Production />} />
        <Route path="/forecast" element={<Forecast />} />
        <Route path="/recommendations" element={<Recommendations />} />
        <Route path="/alerts" element={<Alerts />} />
        <Route path="/analytics" element={<Analytics />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  );
}
