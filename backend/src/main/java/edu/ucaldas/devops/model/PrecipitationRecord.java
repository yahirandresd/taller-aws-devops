package edu.ucaldas.devops.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "precipitation_records")
public class PrecipitationRecord {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @NotNull private LocalDate recordDate;
    @NotBlank @Size(max = 120) private String sector;
    @NotBlank @Size(max = 120) private String stationName;
    @NotNull @DecimalMin("0.0") @Column(precision = 8, scale = 2)
    private BigDecimal precipitationMm;
    @Size(max = 200) private String source;
    @Size(max = 1000) private String observations;

    public Long getId(){return id;} public void setId(Long id){this.id=id;}
    public LocalDate getRecordDate(){return recordDate;} public void setRecordDate(LocalDate recordDate){this.recordDate=recordDate;}
    public String getSector(){return sector;} public void setSector(String sector){this.sector=sector;}
    public String getStationName(){return stationName;} public void setStationName(String stationName){this.stationName=stationName;}
    public BigDecimal getPrecipitationMm(){return precipitationMm;} public void setPrecipitationMm(BigDecimal precipitationMm){this.precipitationMm=precipitationMm;}
    public String getSource(){return source;} public void setSource(String source){this.source=source;}
    public String getObservations(){return observations;} public void setObservations(String observations){this.observations=observations;}
}
