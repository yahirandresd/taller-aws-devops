package edu.ucaldas.devops.controller;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties = {
    "spring.datasource.url=jdbc:h2:mem:controllerdb;DB_CLOSE_DELAY=-1",
    "spring.datasource.driver-class-name=org.h2.Driver",
    "spring.datasource.username=sa",
    "spring.datasource.password=",
    "app.cors.origins=http://localhost:5173"
})
@AutoConfigureMockMvc
class ObservatorioControllerTests {
    @Autowired MockMvc mvc;

    @Test
    void registraLluviaYLaSumaEnElResumen() throws Exception {
        String body = """
            {"recordDate":"2026-10-20","sector":"Chipre","stationName":"Chipre",
             "precipitationMm":12.5,"source":"Prueba QA"}""";
        mvc.perform(post("/api/precipitations").contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id", notNullValue()));

        mvc.perform(get("/api/precipitations").param("date", "2026-10-20"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$[*].sector", hasItem("Chipre")));

        mvc.perform(get("/api/dashboard/summary").param("date", "2026-10-20"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.precipitationRecords", is(1)))
            .andExpect(jsonPath("$.precipitationTotalMm", is(12.5)));
    }

    @Test
    void rechazaPrecipitacionNegativa() throws Exception {
        String body = """
            {"recordDate":"2026-10-20","sector":"Centro","stationName":"Centro","precipitationMm":-1}""";
        mvc.perform(post("/api/precipitations").contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest());
    }

    @Test
    void actualizaEstadoDeIncidenteYRechazaEstadosInvalidos() throws Exception {
        String body = """
            {"recordDate":"2026-10-20","recordTime":"07:30:00","sector":"Av. Santander",
             "locationDescription":"Cable","congestionLevel":"ALTA","cause":"LLUVIA","status":"REPORTADO"}""";
        String created = mvc.perform(post("/api/traffic-incidents").contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isCreated())
            .andReturn().getResponse().getContentAsString();
        Number id = JsonPath.read(created, "$.id");

        mvc.perform(patch("/api/traffic-incidents/" + id + "/status")
                .contentType(MediaType.APPLICATION_JSON).content("{\"status\":\"CERRADO\"}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status", is("CERRADO")));

        mvc.perform(patch("/api/traffic-incidents/" + id + "/status")
                .contentType(MediaType.APPLICATION_JSON).content("{\"status\":\"INVENTADO\"}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void healthEstaArriba() throws Exception {
        mvc.perform(get("/actuator/health"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status", is("UP")));
    }
}
