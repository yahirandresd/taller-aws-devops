package edu.ucaldas.devops.controller;

import edu.ucaldas.devops.model.*;
import edu.ucaldas.devops.repository.*;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class ObservatorioController {
    private final PrecipitationRepository precipitationRepo;
    private final TrafficRepository trafficRepo;
    private final LandslideRepository landslideRepo;

    public ObservatorioController(PrecipitationRepository precipitationRepo,
                                  TrafficRepository trafficRepo,
                                  LandslideRepository landslideRepo) {
        this.precipitationRepo = precipitationRepo;
        this.trafficRepo = trafficRepo;
        this.landslideRepo = landslideRepo;
    }

    @GetMapping("/precipitations")
    public List<PrecipitationRecord> precipitations(
        @RequestParam(required=false) @DateTimeFormat(iso=DateTimeFormat.ISO.DATE) LocalDate date) {
        return date == null ? precipitationRepo.findAll() : precipitationRepo.findByRecordDateOrderBySectorAsc(date);
    }

    @PostMapping("/precipitations")
    @ResponseStatus(HttpStatus.CREATED)
    public PrecipitationRecord createPrecipitation(@Valid @RequestBody PrecipitationRecord body) {
        body.setId(null);
        return precipitationRepo.save(body);
    }

    @GetMapping("/traffic-incidents")
    public List<TrafficIncident> traffic(
        @RequestParam(required=false) @DateTimeFormat(iso=DateTimeFormat.ISO.DATE) LocalDate date) {
        return date == null ? trafficRepo.findAll() : trafficRepo.findByRecordDateOrderByRecordTimeDesc(date);
    }

    @PostMapping("/traffic-incidents")
    @ResponseStatus(HttpStatus.CREATED)
    public TrafficIncident createTraffic(@Valid @RequestBody TrafficIncident body) {
        body.setId(null);
        return trafficRepo.save(body);
    }

    @PatchMapping("/traffic-incidents/{id}/status")
    public TrafficIncident updateTrafficStatus(@PathVariable Long id, @RequestBody Map<String,String> body) {
        TrafficIncident item = trafficRepo.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Reporte no encontrado"));
        String status = body.get("status");
        if (!List.of("REPORTADO","EN_ATENCION","CERRADO").contains(status))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Estado inválido");
        item.setStatus(status);
        return trafficRepo.save(item);
    }

    @GetMapping("/landslides")
    public List<LandslideReport> landslides(
        @RequestParam(required=false) @DateTimeFormat(iso=DateTimeFormat.ISO.DATE) LocalDate date) {
        return date == null ? landslideRepo.findAll() : landslideRepo.findByRecordDateOrderByRecordTimeDesc(date);
    }

    @PostMapping("/landslides")
    @ResponseStatus(HttpStatus.CREATED)
    public LandslideReport createLandslide(@Valid @RequestBody LandslideReport body) {
        body.setId(null);
        return landslideRepo.save(body);
    }

    @GetMapping("/dashboard/summary")
    public Map<String,Object> summary(
        @RequestParam(required=false) @DateTimeFormat(iso=DateTimeFormat.ISO.DATE) LocalDate date) {
        LocalDate day = date == null ? LocalDate.now() : date;
        List<PrecipitationRecord> rain = precipitationRepo.findByRecordDateOrderBySectorAsc(day);
        List<TrafficIncident> traffic = trafficRepo.findByRecordDateOrderByRecordTimeDesc(day);
        List<LandslideReport> landslides = landslideRepo.findByRecordDateOrderByRecordTimeDesc(day);
        BigDecimal total = rain.stream().map(PrecipitationRecord::getPrecipitationMm)
            .filter(v -> v != null).reduce(BigDecimal.ZERO, BigDecimal::add);
        Map<String,Object> result = new LinkedHashMap<>();
        result.put("date", day);
        result.put("precipitationRecords", rain.size());
        result.put("precipitationTotalMm", total);
        result.put("trafficIncidents", traffic.size());
        result.put("landslides", landslides.size());
        result.put("note", "Datos ingresados por usuarios; no representan un dato oficial de la ciudad.");
        return result;
    }
}
